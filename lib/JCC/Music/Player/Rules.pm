package JCC::Music::Player::Rules;

use v5.12;
use warnings;

use Exporter qw/ import /;

use DateTime;
use DateTime::Event::Sunrise;
use Music::Tag;

push our @EXPORT_OK, qw/ genres_to_use update_db_from_file_system /;

sub update_db_from_file_system {
    my ($schema, $music_path, %options) = @_;

    open my $fh, '-|', 'find', $music_path;
    while (my $fn = <$fh>) {
        chomp($fn);

        if (-f $fn && ($fn =~ m{\.mp3$} || $fn =~ m{\.ogg$})) {
            my $row = $schema->resultset('Track')->find_or_new({ filename => $fn, }, { key => 'filename', });
            say STDERR qq{$fn: Added to DB} if $options{verbose} && !$row->in_storage;
            $row->score(1) unless defined $row->score;
            unless (defined $row->genre) {
                my $info = Music::Tag->new($fn);
                $info->get_tag();
                $row->genre($info->genre);
                say STDERR qq{$fn: Assigned genre @{[ $row->genre ]}} if $options{verbose};
            }
            $row->update();
        }
    }
    close $fh;

    my $rs = $schema->resultset('Track')->search_rs();
    while (my $row = $rs->next()) {
        $row->delete() unless -f $row->filename;
    }
}

sub genres_to_use {
    my ($lat, $long) = (32.826788, -97.24239);
    state $sun_local = DateTime::Event::Sunrise->new(latitude  => $lat, longitude => $long);
    state $now = DateTime->now(time_zone => 'America/Chicago');
    my $only_christmas = $now->month == 12 && $now->day > (25 - 7) && $now->day <= 25;
    my $use_christmas =
        $now->month == 11 && $now->day > thanksgiving_day($now)
        || $now->month == 12
    ;
    my $use_sabbath =
        $now->wday == 5 && $now > $sun_local->sunset_datetime($now)->subtract(hours => 1)
        || $now->wday == 6 && $now < $sun_local->sunset_datetime($now)->add(hours => 1)
    ;
    my @secular_genres = ('Country', 'Rock & Roll');
    my @religious_genres = ('Christian', 'Gospel', 'Southern Gospel');
    my @christmas_genres = ('Christmas Songs', 'Winter');
    my @christmas_religious_genres = ('Christmas Carols');
    my @genres;
    if ($use_sabbath && $only_christmas) { @genres = (@christmas_religious_genres); }
    elsif ($use_sabbath && $use_christmas) { @genres = (@religious_genres, @christmas_religious_genres); }
    elsif ($use_sabbath) { @genres = (@religious_genres); }
    elsif ($only_christmas) { @genres = (@christmas_genres, @christmas_religious_genres); }
    elsif ($use_christmas) { @genres = (@secular_genres, @religious_genres, @christmas_genres, @christmas_religious_genres); }
    else { @genres = (@secular_genres, @religious_genres) }

    return @genres;
}

1;

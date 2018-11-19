package JCC::Music::Player::Rules;

use v5.12;
use warnings;

use Exporter qw/ import /;

use DateTime;
use DateTime::Event::Sunrise;
use Music::Tag;
use JSON::XS qw/ decode_json /;

push our @EXPORT_OK, qw/ genres_to_use update_db_from_file_system /;

use constant LOCATION => decode_json scalar qx{curl -s https://freegeoip.app/json/};

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
            $row->num_plays(0) unless defined $row->num_plays;
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
    my (%options) = @_;

    state $sun_local = DateTime::Event::Sunrise->new(latitude  => LOCATION->{latitude}, longitude => LOCATION->{longitude});
    my $now = DateTime->now(time_zone => LOCATION->{time_zone});
    my $only_christmas = $now->month == 12 && $now->day > (25 - 7) && $now->day <= 25;
    my $use_christmas =
        $now->month == 11 && $now->day > thanksgiving_day($now)
        || $now->month == 12
    ;
    my $use_sabbath =
        $now->wday == 5 && $now > $sun_local->sunset_datetime($now)->subtract(hours => 1)
        || $now->wday == 6 && $now < $sun_local->sunset_datetime($now)->add(hours => 1)
    ;
    if ($options{verbose}) {
        printf STDERR "Month: %d; day: %d; dow: %d, Thanksgiving: %s; Sunset: %s\n", $now->month, $now->day, $now->wday, ($now->month == 11 ? thanksgiving_day($now) : ''), ($now->wday == 5 || $now->wday == 6 ? $sun_local->sunset_datetime($now) : '');
        printf STDERR "Only Christmas: %s; Use Christmas: %s; Use Sabbath: %s\n", ($only_christmas ? "Yes" : "No"), ($use_christmas ? "Yes" : "No"), ($use_sabbath ? "Yes" : "No");
    }
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

sub thanksgiving_day {
    my ($now) = @_;

    # Thursday is wday = 4
    my $beg_of_nov = $now->clone()->set_day(1);
    my $first_thursday = $beg_of_nov->clone()->add(days => (4 - $beg_of_nov->wday) % 7);
    my $thanksgiving = $first_thursday->clone()->add(days => 7 * 3); # Fourth Thursday
    return $thanksgiving->day;
}

1;

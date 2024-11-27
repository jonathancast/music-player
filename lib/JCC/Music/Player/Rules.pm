package JCC::Music::Player::Rules;

use v5.12;
use warnings;

use Exporter qw/ import /;

use Try::Tiny;

use DateTime;
use DateTime::Event::Sunrise;
use Music::Tag;

use List::Util qw/ max /;
use File::Slurp qw/ read_file write_file /;
use JSON::XS qw/ decode_json encode_json /;

push our @EXPORT_OK, qw/ category is_sabbath genres_to_use good_genres update_db_from_file_system christmas christmas_genres /;

use constant lat_long_file => qq{$ENV{HOME}/lat-long};

my $lat_long;
BEGIN {
    $lat_long = try { decode_json scalar read_file(lat_long_file) }
        || { latitude => 33.038334, longitude => -97.006111, time_zone => 'America/Chicago', }
    ;
    write_file(lat_long_file, encode_json($lat_long));
}
use constant LOCATION => $lat_long;

sub is_sabbath();
sub good_genres();

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
            if ($row->in_storage) { $row->update(); } else { $row->insert(); }
        }
    }
    close $fh;

    my $rs = $schema->resultset('Track')->search_rs();
    while (my $row = $rs->next()) {
        $row->delete() unless -f $row->filename;
    }
}


state $sun_local = DateTime::Event::Sunrise->new(latitude  => LOCATION->{latitude}, longitude => LOCATION->{longitude});

sub category { is_sabbath ? 'sabbath-music' : 'music'; }

sub is_sabbath() {
    my $now = DateTime->now(time_zone => LOCATION->{time_zone});
    return
        $now->wday == 5 && $now > $sun_local->sunset_datetime($now)->subtract(hours => 1)
        || $now->wday == 6 && $now < $sun_local->sunset_datetime($now)->add(hours => 1)
    ;
}

my @secular_genres = ('Country', 'Rock & Roll');
my @religious_genres = ('Christian', 'Gospel', 'Southern Gospel');
my @christmas_genres = ('Christmas Songs', 'Winter');
my @christmas_religious_genres = ('Christmas Carols');

sub genres_to_use {
    my ($category) = @_;

    return
        {
            'sabbath-music' => [@religious_genres],
            'music' => [@secular_genres, @religious_genres],
        }->{$category}->@*
    ;
}

sub christmas_genres {
    my ($category) = @_;

    return
        {
            'sabbath-music' => [@christmas_religious_genres],
            'music' => [@christmas_genres, @christmas_religious_genres],
        }->{$category}->@*
    ;
}

sub good_genres() { @religious_genres, @christmas_genres, @christmas_religious_genres }

sub christmas {
    my $now = DateTime->now(time_zone => LOCATION->{time_zone});

    my $thanksgiving = $now->clone()->truncate(to => 'day')->set_month(11)->set_day(1) # beginning of November
        ->truncate(to => 'week')->add(days => 3) # First Thursday
        ->add(days => 7 * 3) # Fourth Thursday
    ;
    my $christmas = $now->clone()->truncate(to => 'day')->set_month(12)->set_day(25);
    my $now_epoch = $now->epoch;
    my $end_of_thanksgiving = $sun_local->sunset_datetime($thanksgiving)->epoch;
    my $beg_of_christmas = $sun_local->sunset_datetime($christmas->clone->subtract(days => 1))->subtract(hours => 1)->epoch;
    my $end_of_christmas = $sun_local->sunset_datetime($christmas)->add(hours => 1)->epoch;
    my $end_of_year = $now->clone()->truncate(to => 'year')->add(years => 1)->epoch;

    return $now_epoch < $end_of_thanksgiving ? ''
        : $now_epoch < $beg_of_christmas ? rand() <= ($now_epoch - $end_of_thanksgiving) / ($beg_of_christmas - $end_of_thanksgiving)
        : $now_epoch < $end_of_christmas ? 1
        : rand() >= ($now_epoch - $end_of_christmas) / ($end_of_year - $end_of_christmas)
    ;
}

1;

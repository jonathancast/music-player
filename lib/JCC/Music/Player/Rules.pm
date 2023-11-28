package JCC::Music::Player::Rules;

use v5.12;
use warnings;

use Exporter qw/ import /;

use Try::Tiny;

use DateTime;
use DateTime::Event::Sunrise;
use Music::Tag;

use File::Slurp qw/ read_file write_file /;
use JSON::XS qw/ decode_json encode_json /;

push our @EXPORT_OK, qw/ category is_sabbath genres_to_use good_genres update_db_from_file_system enforce_christmas christmas_genres /;

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
            $row->update();
        }
    }
    close $fh;

    my $rs = $schema->resultset('Track')->search_rs();
    while (my $row = $rs->next()) {
        $row->delete() unless -f $row->filename;
    }
}


state $sun_local = DateTime::Event::Sunrise->new(latitude  => LOCATION->{latitude}, longitude => LOCATION->{longitude});

sub category {
    my (%options) = @_;

    my $now = DateTime->now(time_zone => LOCATION->{time_zone});
    my $only_christmas = $now->month == 12 && $now->day > (25 - 7) && $now->day <= 25;
    my $use_christmas =
        $now->month == 11 && $now->day > thanksgiving_day($now)
        || $now->month == 12
    ;
    if ($options{verbose}) {
        printf STDERR "Month: %d; day: %d; dow: %d, Thanksgiving: %s; Sunset: %s\n", $now->month, $now->day, $now->wday, ($now->month == 11 ? thanksgiving_day($now) : ''), ($now->wday == 5 || $now->wday == 6 ? $sun_local->sunset_datetime($now) : '');
        printf STDERR "Only Christmas: %s; Use Christmas: %s; Use Sabbath: %s\n", ($only_christmas ? "Yes" : "No"), ($use_christmas ? "Yes" : "No"), (is_sabbath ? "Yes" : "No");
    }

    return is_sabbath && $only_christmas ? 'sabbath-only-christmas-music'
        : is_sabbath && $use_christmas ? 'sabbath-christmas-music'
        : is_sabbath ? 'sabbath-music'
        : $only_christmas ? 'only-christmas-music'
        : $use_christmas ? 'christmas-music'
        : 'music'
    ;
}

sub enforce_christmas {
    my $now = DateTime->now(time_zone => LOCATION->{time_zone});

    if ($now->month == 11 && $now->day > thanksgiving_day($now)) {
        my $days_until_christmas = 25 + 30 - $now->day;
        return rand() * 30 > $days_until_christmas - 7;
    } elsif ($now->month == 12 && $now->day <= 25) {
        my $days_until_christmas = 25 - $now->day;
        return rand() * 30 > $days_until_christmas - 7;
    } elsif ($now->month == 12 && $now->day > 25) {
        my $days_past_christmas = $now->day - 25;
        return rand() * 7 > $days_past_christmas;
    } else {
        return '';
    }
}

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
            'sabbath-only-christmas-music' => [@christmas_religious_genres],
            'sabbath-christmas-music' => [@religious_genres, @christmas_religious_genres],
            'sabbath-music' => [@religious_genres],
            'only-christmas-music' => [@christmas_genres, @christmas_religious_genres],
            'christmas-music' => [@secular_genres, @religious_genres, @christmas_genres, @christmas_religious_genres],
            'music' => [@secular_genres, @religious_genres],
        }->{$category}->@*
    ;
}

sub christmas_genres {
    my ($category) = @_;

    return
        {
            'sabbath-only-christmas-music' => [@christmas_religious_genres],
            'sabbath-christmas-music' => [@christmas_religious_genres],
            'sabbath-music' => [],
            'only-christmas-music' => [@christmas_genres, @christmas_religious_genres],
            'christmas-music' => [@christmas_genres, @christmas_religious_genres],
            'music' => [],
        }->{$category}->@*
    ;
}

sub good_genres() { @religious_genres, @christmas_genres, @christmas_religious_genres }

sub thanksgiving_day {
    my ($now) = @_;

    # Thursday is wday = 4
    my $beg_of_nov = $now->clone()->set_day(1);
    my $first_thursday = $beg_of_nov->clone()->add(days => (4 - $beg_of_nov->wday) % 7);
    my $thanksgiving = $first_thursday->clone()->add(days => 7 * 3); # Fourth Thursday
    return $thanksgiving->day;
}

1;

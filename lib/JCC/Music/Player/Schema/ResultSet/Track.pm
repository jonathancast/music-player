use Moops;

use v5.24;

class JCC::Music::Player::Schema::ResultSet::Track extends DBIx::Class::ResultSet {
    __PACKAGE__->load_components('Helper::ResultSet::CorrelateRelationship');
    __PACKAGE__->load_components('Helper::ResultSet::IgnoreWantarray');
    __PACKAGE__->load_components('Helper::ResultSet::Me');
    __PACKAGE__->load_components('Helper::ResultSet::Shortcut');

    method nth_row($target) {
        $target += 0;

        my ($prev_sql, @prev_params) = $self->correlate('previous_tracks')->get_column('score')->sum_rs()->as_query()->$*->@*;

        return $self
            ->search({ -and => [
                \[ qq{$prev_sql <= $target}, @prev_params, ],
                \[ qq{$target <= $prev_sql + @{[ $self->me.'score' ]}}, @prev_params, ],
            ], })
            ->limit(1)
        ;
    }
}

1;

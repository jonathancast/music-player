use Moops;

use v5.24;

class JCC::Music::Player::Schema::ResultSet::Track extends DBIx::Class::ResultSet {
    use JCC::Music::Player::Rules qw/ good_genres /;

    __PACKAGE__->load_components('Helper::ResultSet::CorrelateRelationship');
    __PACKAGE__->load_components('Helper::ResultSet::IgnoreWantarray');
    __PACKAGE__->load_components('Helper::ResultSet::Me');
    __PACKAGE__->load_components('Helper::ResultSet::Shortcut');

    method apply_threshold($threshold) {
        $self->search(\[
            qq{case when genre in (@{[ join(',', map { '?' } good_genres) ]}) then @{[ $self->me('score') ]} >= ? else score >= ? end},
            good_genres, $threshold / 100 / 2, $threshold / 100,
        ])
    }

    method nth_row {
        my $target = rand() * $self->result_source->resultset->get_column('score')->sum();

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

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
        return $self
            ->order_by(\q{random()})
            ->limit(1)
        ;
    }
}

1;

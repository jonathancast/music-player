package JCC::Music::Player::Schema::Result::Track;

use v5.12;
use warnings;

use DBIx::Class::Candy -autotable => v1, -perl5 => v12;

primary_column id => { data_type => 'int', is_auto_increment => 1, };

column filename => { data_type => 'text', };
column genre => { data_type => 'text', };

column score => { data_type => 'real', };

unique_constraint filename => [qw/ filename /];

has_many previous_tracks => 'JCC::Music::Player::Schema::Result::Track', sub {
    my $args = shift;

    return {
        "$args->{foreign_alias}.id" => { '<' => { -ident => "$args->{self_alias}.id" }, },
    };
};

sub add_score {
    my ($self, $new_score) = @_;

    my $weight = 0.5;

    $self->update({ score => $self->score * (1 - $weight) + $new_score * $weight, });
}

1;

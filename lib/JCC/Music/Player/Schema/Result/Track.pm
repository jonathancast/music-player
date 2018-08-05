package JCC::Music::Player::Schema::Result::Track;

use v5.12;
use warnings;

use DBIx::Class::Candy -autotable => v1, -perl5 => v12;

primary_column id => { data_type => 'int', is_auto_increment => 1, };

column filename => { data_type => 'text', };
column genre => { data_type => 'text', };

column score => { data_type => 'real', };
column num_plays => { data_type => 'int', };

unique_constraint filename => [qw/ filename /];

has_many previous_tracks => 'JCC::Music::Player::Schema::Result::Track', sub {
    my $args = shift;

    return {
        "$args->{foreign_alias}.id" => { '<' => { -ident => "$args->{self_alias}.id" }, },
    };
};

sub score_pct { shift->score * 100 }

sub add_score {
    my ($self, $new_score) = @_;

    $self->update({
        score => ($self->score * ($self->num_plays + 0.5) + $new_score) / ($self->num_plays + 0.5 + 1),
        num_plays => $self->num_plays + 1,
    });
}

1;

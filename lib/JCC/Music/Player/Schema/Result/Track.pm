package JCC::Music::Player::Schema::Result::Track;

use v5.12;
use warnings;

use DBIx::Class::Candy -autotable => v1, -perl5 => v12;

use List::Util qw/ max min /;

primary_column id => { data_type => 'int', is_auto_increment => 1, };

column filename => { data_type => 'text', };
column genre => { data_type => 'text', };

column score => { data_type => 'real', };
column num_plays => { data_type => 'int', };

unique_constraint filename => [qw/ filename /];

sub score_pct { shift->score * 100 }

sub add_score {
    my ($self, $increment) = @_;

    my $new_score = ($self->score * $self->num_plays + $increment) / ($self->num_plays + 1);
    $new_score = max(0, $self->score - 0.1, $self->score / 2, $new_score);
    $new_score = min(1, $self->score + 0.1, ($self->score + 1) / 2, $new_score);

    $self->update({ score => $new_score, num_plays => $self->num_plays + 1, });
}

1;

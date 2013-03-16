# ABSTRACT: Unregister packages from a stack

package Pinto::Action::Unregister;

use Moose;
use MooseX::Types::Moose qw(Bool);
use MooseX::MarkAsMethods (autoclean => 1);

use Pinto::Exception qw(throw);
use Pinto::Types qw(SpecList StackName StackDefault StackObject);

#------------------------------------------------------------------------------

# VERSION

#------------------------------------------------------------------------------

extends qw( Pinto::Action );

#------------------------------------------------------------------------------

with qw( Pinto::Role::Committable );

#------------------------------------------------------------------------------

has targets   => (
    isa      => SpecList,
    traits   => [ qw(Array) ],
    handles  => {targets => 'elements'},
    required => 1,
    coerce   => 1,
);


has stack => (
    is        => 'ro',
    isa       => StackName | StackDefault | StackObject,
    default   => undef,
);


has force => (
    is        => 'ro',
    isa       => Bool,
    default   => 0,
);

#------------------------------------------------------------------------------


sub execute {
    my ($self) = @_;

    my $stack = $self->repo->get_stack($self->stack)->start_revision;

    my @dists = map { $self->_unregister($_, $stack) } $self->targets;
    return $self->result if $self->dry_run or $stack->has_not_changed;

    my $msg_title = $self->generate_message_title(@dists);
    my $msg = $self->compose_message(stack => $stack, title => $msg_title);

    $stack->commit_revision(message => $msg);

    return $self->result->changed;
}

#------------------------------------------------------------------------------

sub _unregister {
    my ($self, $target, $stack) = @_;

    my $dist = $stack->get_distribution(spec => $target);
    throw "$target is not registered on stack $stack" if not defined $dist;

    $dist->unregister(stack => $stack, force => $self->force);

    return $dist;
}

#------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#------------------------------------------------------------------------------

1;

__END__
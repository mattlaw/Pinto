# ABSTRACT: Something that makes HTTP requests

package Pinto::Role::UserAgent;

use Moose::Role;
use MooseX::MarkAsMethods ( autoclean => 1 );

use URI;
use URI::file;
use Path::Class;
use LWP::UserAgent;

use Pinto::Globals;
use Pinto::Util qw(itis debug throw tempdir make_uri);

#-----------------------------------------------------------------------------

# VERSION

#-----------------------------------------------------------------------------

=method fetch(from => 'http://someplace' to => 'some/path')

Fetches the file located at C<from> to the file located at C<to>, if
the file at C<from> is newer than the file at C<to>.  If the
intervening directories do not exist, they will be created for you.
Returns a true value if the file has changed, returns false if it has
not changed.  Throws and exception if anything goes wrong.

The C<from> argument can be either a L<URI> or L<Path::Class::File>
object, or a string that represents either of those.  The C<to>
attribute can be a L<Path::Class::File> object or a string that
represents one.

=cut

sub fetch {
    my ( $self, %args ) = @_;

    my $from     = $args{from};
    my $from_uri = make_uri($from);
    my $to       = itis( $args{to}, 'Path::Class' ) ? $args{to} : file( $args{to} );

    debug("Skipping $from: already fetched to $to") and return 0 if -e $to;

    $to->parent->mkpath if not -e $to->parent;
    my $has_changed = $self->_fetch( $from_uri, $to );

    return $has_changed;
}

#------------------------------------------------------------------------------

=method fetch_temporary(uri => 'http://someplace')

Fetches the file located at the C<uri> to a file in a temporary
directory.  The file will have the same basename as the C<uri>.
Returns a L<Path::Class::File> that points to the new file.  Throws
and exception if anything goes wrong.  Note the temporary directory
and all its contents will be deleted when the process terminates.

=cut

sub fetch_temporary {
    my ( $self, %args ) = @_;

    my $uri  = URI->new( $args{uri} )->canonical;
    my $path = file( $uri->path );
    return $path if $uri->scheme() eq 'file';

    my $base     = $path->basename;
    my $tempfile = file( tempdir, $base );

    $self->fetch( from => $uri, to => $tempfile );

    return file($tempfile);
}

#------------------------------------------------------------------------------

sub head { 
    my ($self, @args) = @_;

    # TODO: Argument check?
    debug sub { $args[0]->as_string(0) };
    return $Pinto::Globals::UA->head(@args);
}

#------------------------------------------------------------------------------
sub request {
    my ($self, @args) = @_;

    # TODO: Argument check?
    debug sub { $args[0]->as_string(0) };
    return $Pinto::Globals::UA->request(@args);
}

#------------------------------------------------------------------------------

sub _fetch {
    my ( $self, $uri, $to ) = @_;

    debug("Fetching $uri");

    my $result = eval { $Pinto::Globals::UA->mirror( $uri, $to ) }
        or throw $@;

    if ( $result->is_success() ) {
        return 1;
    }
    elsif ( $result->code() == 304 ) {
        return 0;
    }
    else {
        throw "Failed to fetch $uri: " . $result->status_line;
    }

    # Should never get here
}

#-----------------------------------------------------------------------------
1;

__END__
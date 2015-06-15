package Dist::Zilla::Plugin::PreviousVersion::Changelog;
# ABSTRACT: extract previous version from changelog

=head1 DESCRIPTION

Plugin implementing the L<Dist::Zilla::Role::PreviousVersionProvider> role.
It provides the previous released version by peeking at the C<Changelog> file
and returning its latest release, skipping over C<{{$NEXT}}> if its there
(see L<Dist::Zilla::Plugin::NextRelease>).

Note that this module uses L<CPAN::Changes> to parse the change log. If the
file is not well-formed according to its specs, strange things might happen.

=head1 CONFIGURATION

=head2 filename

Changelog filename. Defaults to 'Changes'.

=cut

use strict;
use warnings;

use CPAN::Changes;
use List::Util qw/ first /;

use Moose;

with qw/ 
    Dist::Zilla::Role::Plugin
    Dist::Zilla::Role::YANICK::PreviousVersionProvider
/;

has filename  => ( is => 'ro', isa=>'Str', default => 'Changes' );

has changelog => (
    is => 'ro',
    isa => 'CPAN::Changes',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $changes_file = first { $_->name eq $self->filename }
                                 @{ $self->zilla->files }
            or $self->log_fatal(
                    "changelog '@{[ $self->filename ]}' not found" );

        CPAN::Changes->load_string(
            $changes_file->content,
            next_token => qr/\{\{\$NEXT\}\}/
        );
    },
);

sub provide_previous_version {
    my $self = shift;

    # TODO {{$NEXT}} not generic enough
    return first { $_ ne '{{$NEXT}}' } 
           map   { $_->version }
           reverse $self->changelog->releases;
}

__PACKAGE__->meta->make_immutable;

1;

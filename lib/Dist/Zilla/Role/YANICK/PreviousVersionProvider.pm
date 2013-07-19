package Dist::Zilla::Role::YANICK::PreviousVersionProvider;
#ABSTRACT: provides the distribution's previously released version

=head1 DESCRIPTION

Role for L<Dist::Zilla::Plugin> classes that return
the previously released version.

The namespace contains I<YANICK> simply because I didn't want
to encroach on the official namespace without asking permission.
If allowed, this role will migrate to
I<Dist::Zilla::Role::PreviousVersionProvider>.

=head1 METHODS REQUIRED BY THE ROLE

=head2 provide_previous_version

Returns the previously released version

=cut

use strict;
use warnings;

use Moose::Role;

requires 'provide_previous_version';


1;

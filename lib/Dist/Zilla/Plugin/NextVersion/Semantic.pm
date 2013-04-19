package Dist::Zilla::Plugin::NextVersion::Semantic;
# ABSTRACT: update the next version, semantic-wise

=head1 SYNOPSIS

    # in dist.ini
    [NextVersion::Semantic]
    major = MAJOR, API CHANGE
    minor = MINOR, ENHANCEMENTS
    revision = REVISION, BUG FIXES

=head1 DESCRIPTION

Increases the distribution's version according to the semantic versioning rules
(see L<http://semver.org/>) by inspecting the changelog. 

More specifically, the plugin performs the following actions:

=over

=item at build time

Reads the changelog using C<CPAN::Changes> and filters out of the C<{{$NEXT}}>
release section any group without item.

=item before a release

Ensures that there is at least one recorded change in the changelog, and
increments the version number in consequence.   If there are changes given
outside of the sections, they are considered to be minor.

=item after a release

Updates the new C<{{$NEXT}}> section of the changelog with placeholders for
all the change categories.  With categories as given in the I<SYNOPSIS>,
this would look like

    {{$NEXT}}

      [MAJOR]

      [API CHANGE]

      [MINOR]

      [ENHANCEMENTS]

      [REVISION]

      [BUG FIXES]

=back

If a version is given via the environment variable C<V>, it will taken
as-if as the next version.

For this plugin to work, your L<Dist::Zilla> configuration must also contain a plugin 
consuming the L<Dist::Zilla::Role::YANICK::PreviousVersionProvider> role.

=cut

use strict;
use warnings;

use CPAN::Changes 0.17;
use Perl::Version;

use Moose;

with qw/
    Dist::Zilla::Role::Plugin
    Dist::Zilla::Role::FileMunger
    Dist::Zilla::Role::TextTemplate
    Dist::Zilla::Role::BeforeRelease
    Dist::Zilla::Role::AfterRelease
    Dist::Zilla::Role::VersionProvider
/;

use Moose::Util::TypeConstraints;

subtype 'ChangeCategory',
    as 'ArrayRef[Str]';

coerce ChangeCategory =>
    from 'Str',
    via {
        [ split /\s*,\s*/, $_ ]
    };

=head1 PARAMETERS

=head2 change_file

File name of the changelog. Defaults to C<Changes>.

=cut

has change_file  => ( is => 'ro', isa=>'Str', default => 'Changes' );

=head2 numify_version

If B<true>, the version will be a number using the I<x.yyyzzz> convention instead 
of I<x.y.z>.  Defaults to B<false>.

=cut

has numify_version => ( is => 'ro', isa => 'Bool', default => 0 );


=head2 major

Comma-delimited list of categories of changes considered major.
Defaults to C<API CHANGES>.

=cut

has major => (
    is => 'ro',
    isa => 'ChangeCategory',
    coerce => 1,
    default => sub { [ 'API CHANGES' ] },
    traits  => ['Array'],
    handles => { major_groups => 'elements' },
);

=head2 minor

Comma-delimited list of categories of changes considered minor.
Defaults to C<ENHANCEMENTS>.

=cut

has minor => (
    is => 'ro',
    isa => 'ChangeCategory',
    coerce => 1,
    default => sub { [ 'ENHANCEMENTS' ] },
    traits  => ['Array'],
    handles => { minor_groups => 'elements' },
);

=head2 revision

Comma-delimited list of categories of changes considered revisions.
Defaults to C<BUG FIXES, DOCUMENTATION>.

=cut

has revision => (
    is => 'ro',
    isa => 'ChangeCategory',
    coerce => 1,
    default => sub { [ 'BUG FIXES', 'DOCUMENTATION' ] },
    traits  => ['Array'],
    handles => { revision_groups => 'elements' },
);

sub before_release {
    my $self = shift;

    my ($changes_file) = grep { $_->name eq $self->change_file } @{ $self->zilla->files };

  my $changes = CPAN::Changes->load_string( 
      $changes_file->content, 
      next_token => qr/{{\$NEXT}}/ 
  ); 

  my( $next ) = reverse $changes->releases;

  my @changes = values %{ $next->changes };

  $self->log_fatal("change file has no content for next version")
    unless @changes;

}

sub after_release {
  my ($self) = @_;
  my $filename = $self->change_file;

  my $changes = CPAN::Changes->load( 
      $self->change_file, 
      next_token => qr/{{\$NEXT}}/ 
  ); 

  # remove empty groups
  $changes->delete_empty_groups;

  my ( $next ) = reverse $changes->releases;

  $next->add_group( $self->all_groups );

  $self->log_debug([ 'updating contents of %s on disk', $filename ]);

  # and finally rewrite the changelog on disk
  open my $out_fh, '>', $filename
    or Carp::croak("can't open $filename for writing: $!");

  print $out_fh $changes->serialize;

  close $out_fh or Carp::croak("error closing $filename: $!");
}

sub all_groups {
    my $self = shift;

    return map { $self->$_ } map { $_.'_groups' } qw/ major minor revision /
}

has previous_version => (
    is => 'ro',
    lazy => 1, 
    default => sub {
        my $self = shift;

        my $plugins =
            $self->zilla->plugins_with('-YANICK::PreviousVersionProvider');

        $self->log_fatal( 
            "at least one plugin with the role PreviousVersionProvider is required" 
        ) unless ref $plugins and @$plugins >= 1;

        for my $plugin ( @$plugins ) {
            my $version = $plugin->provide_previous_version;

            return $version if defined $version;
        }

        $self->log_fatal('no previous version found');

    },
);

sub provide_version {
  my $self = shift;

  # override (or maybe needed to initialize)
  return $ENV{V} if exists $ENV{V};

  my $new_ver = $self->next_version( $self->previous_version);

  $self->zilla->version("$new_ver");
}

sub next_version {
    my( $self, $last_version ) = @_;

    my ($changes_file) = grep { $_->name eq $self->change_file } @{ $self->zilla->files };

    my $changes = CPAN::Changes->load_string( $changes_file->content,
        next_token => qr/{{\$NEXT}}/ ); 

    my ($next) = reverse $changes->releases;

    my $new_ver = $self->inc_version( 
        $last_version, 
        grep { scalar @{ $next->changes($_) } } $next->groups
    );

    $new_ver = $new_ver->numify if $self->numify_version;

    $self->log("Bumping version from $last_version to $new_ver");
    return $new_ver;
}

sub inc_version {
    my ( $self, $last_version, @groups ) = @_;

    $last_version = Perl::Version->new( $last_version );

    for ( $self->major_groups ) {
        next unless $_ ~~ @groups;

        $self->log_debug( "$_ change detected, major increase" );

        $last_version->inc_revision;
        return $last_version
    }

    for ( '', $self->minor_groups ) {
        next unless $_ ~~ @groups;

        my $section = $_ || 'general';
        $self->log_debug( "$section change detected, minor increase" );

        $last_version->inc_version;
        return $last_version
    }

    $self->log_debug( "revision increase" );

    $last_version->inc_subversion;
    return $last_version;
}

sub munge_files {
  my ($self) = @_;

  my ($file) = grep { $_->name eq $self->change_file } @{ $self->zilla->files };
  return unless $file;

  my $changes = CPAN::Changes->load_string( $file->content, 
      next_token => qr/{{\$NEXT}}/
  );

  my ( $next ) = reverse $changes->releases;

  $next->delete_group($_) for grep { !@{$next->changes($_)} } $next->groups;

  $self->log_debug([ 'updating contents of %s in memory', $file->name ]);
  $file->content($changes->serialize);
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;


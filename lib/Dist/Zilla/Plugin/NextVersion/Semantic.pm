package Dist::Zilla::Plugin::NextVersion::Semantic;
# ABSTRACT: update the next version, semantic-wise

use strict;
use warnings;

use CPAN::Changes 0.20;
use Perl::Version;
use List::MoreUtils qw/ any /;

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
            "at least one plugin with the role PreviousVersionProvider",
            "must be referenced in dist.ini"
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

    for my $group ( $self->major_groups ) {
        next unless any { $group eq $_ } @groups;

        $self->log_debug( "$group change detected, major increase" );

        $last_version->inc_revision;
        return $last_version
    }

    for my $group ( '', $self->minor_groups ) {
        next unless any { $group eq $_ } @groups;

        my $section = $group || 'general';
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


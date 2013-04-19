use strict;
use warnings;

use Test::More tests => 7;
use Test::Exception;

use Test::DZil;

my $changes = make_changes(<<'END_CHANGES');
    - got included in an awesome test suite
END_CHANGES

my $dist_ini = make_dist_ini();

my $tzil = make_tzil( $dist_ini, $changes );

$tzil->build;

like $tzil->slurp_file('build/Changes'),
    qr/0\.1\.0/,
    "regular change, count as minor change";

$tzil = make_tzil( $dist_ini, make_changes(<<'END') );
    [API CHANGES]
    - Game changer
END

$tzil->build;

like $tzil->slurp_file('build/Changes'),
    qr/1\.0\.0/,
    "major change";

$tzil = make_tzil( $dist_ini, make_changes(<<'END') );
    [DOCUMENTATION]
    - Small potatoes
END

$tzil->build;

like $tzil->slurp_file('build/Changes'),
    qr/0\.0\.2/,
    "revision change";

$tzil = make_tzil( make_dist_ini( numify_version => 1 ), make_changes(<<'END') );
    [DOCUMENTATION]
    - Small potatoes
END

$tzil->build;

like $tzil->slurp_file('build/Changes'),
    qr/0\.000002/,
    "numify";

{ 
    local $ENV{V} = '6.6.6';

    $tzil = make_tzil( make_dist_ini(), make_changes(<<'END') );
    [DOCUMENTATION]
    - Small potatoes
END

    $tzil->build;

    like $tzil->slurp_file('build/Changes'),
        qr/6\.6\.6/,
        "override with \$ENV{V}";
}

$tzil = make_tzil( make_dist_ini(), make_changes('') );
throws_ok
    { $tzil->release; }
    qr/change file has no content for next version/,
    'release must fail if there are no recorded changes';

$tzil = make_tzil( make_dist_ini( pvp => 0 ), make_changes('') );
throws_ok
    { $tzil->build; }
    qr/one plugin with the role PreviousVersionProvider is required/,
    'must throw correct error if no PreviousVersionProvider loaded';

### utility functions

sub make_tzil {
    my ( $dist_ini, $changes ) = @_;

    my $tzil = Builder->from_config(
        { dist_root => 'corpus' },
        {
        add_files => {
            'source/Changes' => $changes,
            'source/dist.ini' => $dist_ini
        },
        },
    );
}
sub make_dist_ini {
    my %args = ( pvp => 1, @_ );
    dist_ini({
        name     => 'DZT-Sample',
        abstract => 'Sample DZ Dist',
        author   => 'E. Xavier Ample <example@example.org>',
        license  => 'Perl_5',
        copyright_holder => 'E. Xavier Ample',
    }, qw/
        GatherDir
        FakeRelease
        NextRelease
    /,
    ( $args{'pvp'} ? 'PreviousVersion::Changelog' : () ),
    [ 'NextVersion::Semantic' => { @_ } ]
    );
}

sub make_changes {
    return sprintf <<'END_CHANGES', shift;
Revision history for {{$dist->name}}

{{$NEXT}}
%s

0.0.1     2009-01-02
    - finally left home, proving to mom I can make it!

END_CHANGES
}

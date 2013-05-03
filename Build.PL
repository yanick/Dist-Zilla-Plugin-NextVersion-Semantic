
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "File::Find" => 0,
    "File::Temp" => 0,
    "Module::Build" => "0.3601",
    "Test::DZil" => 0,
    "Test::Exception" => 0,
    "Test::More" => "0.88"
  },
  "configure_requires" => {
    "Module::Build" => "0.3601"
  },
  "dist_abstract" => "update the next version, semantic-wise",
  "dist_author" => [
    "Yanick Champoux <yanick\@cpan.org>"
  ],
  "dist_name" => "Dist-Zilla-Plugin-NextVersion-Semantic",
  "dist_version" => "0.1.2",
  "license" => "perl",
  "module_name" => "Dist::Zilla::Plugin::NextVersion::Semantic",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "CPAN::Changes" => "0.20",
    "Dist::Zilla::Role::AfterRelease" => 0,
    "Dist::Zilla::Role::BeforeRelease" => 0,
    "Dist::Zilla::Role::FileMunger" => 0,
    "Dist::Zilla::Role::Plugin" => 0,
    "Dist::Zilla::Role::TextTemplate" => 0,
    "Dist::Zilla::Role::VersionProvider" => 0,
    "List::Util" => 0,
    "Moose" => 0,
    "Moose::Role" => 0,
    "Moose::Util::TypeConstraints" => 0,
    "Perl::Version" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "script_files" => []
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;

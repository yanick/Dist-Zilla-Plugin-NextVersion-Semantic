requires "CPAN::Changes" => "0.20";
requires "Dist::Zilla::Role::AfterRelease" => "0";
requires "Dist::Zilla::Role::BeforeRelease" => "0";
requires "Dist::Zilla::Role::FileMunger" => "0";
requires "Dist::Zilla::Role::Plugin" => "0";
requires "Dist::Zilla::Role::TextTemplate" => "0";
requires "Dist::Zilla::Role::VersionProvider" => "0";
requires "List::AllUtils" => "0";
requires "List::Util" => "0";
requires "Moose" => "0";
requires "Moose::Role" => "0";
requires "Moose::Util::TypeConstraints" => "0";
requires "Perl::Version" => "0";
requires "perl" => "v5.10.0";
requires "strict" => "0";
requires "warnings" => "0";

on 'build' => sub {
  requires "Module::Build" => "0.28";
};

on 'test' => sub {
  requires "File::Spec" => "0";
  requires "IO::Handle" => "0";
  requires "IPC::Open3" => "0";
  requires "Test::DZil" => "0";
  requires "Test::Exception" => "0";
  requires "Test::More" => "0.88";
};

on 'configure' => sub {
  requires "Module::Build" => "0.28";
};

on 'develop' => sub {
  requires "version" => "0.9901";
};

use inc::Module::Install;
name 'YouTubeDL';
all_from 'lib/YouTubeDL.pm';

requires 'DBI';
requires 'Amon2::Lite';
requires 'Amon2::Plugin::DBI';
requires 'IPC::Cmd';
requires 'AnyEvent';
requires 'AnyEvent::Handle';
requires 'Coro';
requires 'Class::Unload';
requires 'File::Zglob';
requires 'Furl';
requires 'Net::LastFM';
requires 'Path::Class';
requires 'Plack';
requires 'Plack::Builder';
requires 'SQL::Abstract';
requires 'Smart::Args';
requires 'Try::Tiny';
requires 'XML::Atom';
requires 'autodie';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;

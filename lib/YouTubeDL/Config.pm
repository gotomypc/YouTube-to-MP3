package YouTubeDL::Config;
use 5.10.0;
use warnings;
use Path::Class;
use Carp;
use parent qw/Exporter/;
@EXPORT_OK = qw/config/;

my $config;
my $filename = file(__FILE__)->dir->parent->parent->file('config');
sub config {
	$config //= do $filename;
	
	Carp::croak("$filename: $@") if $@;
	Carp::croak("$filename: $!") unless defined $config;                               
	unless ( ref($config) eq 'HASH' ) {
	    Carp::croak("$filename does not return HashRef.");
	}
	return $config;
}

1;

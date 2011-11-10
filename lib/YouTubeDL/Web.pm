package YouTubeDL::Web;
use 5.10.0;
use warnings;
use YouTubeDL::Model;

BEGIN {
	no strict "refs";
	no warnings "redefine"; 
	
	my $package = "Amon2::Web";
	for my $method (qw/res_200 res_404 render_text model/) {
		*{"$package\::$method"} = \&{__PACKAGE__ . "::$method"};
	}
};

sub res_200 {
	my ($c) = @_;
	my $body = "200 OK";
	return $c->create_response(200, [
		'Content-Type'   => "text/plain",
		'Content-Length' => length($body),
	], $body);
}

sub res_404 {
	my ($c) = @_;
	my $body = "404 Not Found";
	return $c->create_response(404, [
		'Content-Type'   => "text/plain",
		'Content-Length' => length($body),
	], $body);
}

sub render_text {
	my ($c, $text) = @_;
	return $c->create_response(200, [
		'Content-Type'   => "text/plain",
		'Content-Length' => length($text),
	], $text);
}

my $model_object;
sub model { $model_object //= bless {}, "YouTubeDL::Model" }

1;

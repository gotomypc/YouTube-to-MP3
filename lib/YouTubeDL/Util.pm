package YouTubeDL::Util;
use 5.10.0;
use warnings;
use Encode;
use Term::ANSIColor qw/colored/;
use List::Util qw/sum/;
use parent qw/Exporter/;
our @EXPORT_OK = qw/truncate_mb dbg err/;

sub truncate_mb {
    my ($str, $max_size, $suffix) = @_;
	$str      //= "";
    $max_size //= 32;
    $suffix   //= "...";

	my @each_len = map { length(encode_utf8($_)) > 1 ? 2 : 1 } split "", $str;
	my $total_len = sum(@each_len);
	
	return $str if $total_len <= $max_size;
	for (my $i = scalar(@each_len) - 1; 0 <= $i; $i--) {
		$total_len -= $each_len[$i];
		if ($total_len + length($suffix) <= $max_size) {
			return substr($str, 0, $i) . $suffix;
		}
	}
}

sub dbg { say(encode_utf8($_)) for @_ }

sub err {
    my ($file, $line) = (caller(0))[1, 2];
	for (@_) {
		next unless defined $_;
		chomp $_;
	    print STDERR colored("$_ at $file line $line\n", 'red') for @_;
	}
}

1;

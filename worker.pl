#!perl
use 5.10.0;
use warnings;
use utf8;
use Encode;
use Path::Class qw/file dir/;
use File::Copy qw/move/;
use autodie;
use URI;
use Try::Tiny;
use Cwd qw/getcwd/;
use AnyEvent;
use AnyEvent::Handle;
use lib file(__FILE__)->dir->subdir('lib')->stringify;
use YouTubeDL::Util qw/dbg err/;
use YouTubeDL::Model qw/model/;
use YouTubeDL::Config qw/config/;
use IPC::Cmd qw/run_forked/;
use File::Zglob;

dbg("daemon started");

my $queue_file = do {
	my $file = file(__FILE__)->dir->file('.queue');
	$file->touch unless -f $file;
	$file;
};
open(my $fh, "tail -f -n 0 $queue_file 2>&1 |");

my $cv = AE::cv;
my $handle; $handle = AnyEvent::Handle->new(fh => $fh);
my $w; 
my $read; $read = sub {
    $handle->push_read(line => sub {
        my ($handle, $line) = @_; 
        $w = AE::timer(0, 0, $read);

		if (fork ~~ 0) {
			chomp $line;
			main($line);
			exit 0;
		}
    }); 
};
$w = AE::timer(0, 0, $read);

my $t; $t = AE::timer(0, 60 * 3, \&cleanup);

$cv->recv;


sub main {
	my $video_id  = shift;
	my $video_url = "http://www.youtube.com/watch?v=$video_id";
	
	my $title  = get_title($video_url);
	
	dbg("start download: id[$video_id]");
	
	my $filename = download($video_url, {
		on_progress => sub {
			#dbg("...$_[0]%");
			change_status($video_id, "update", {
				progress => shift,
				title    => $title
			});
		},
	});
	unless ($filename) {
		err("download failed: id[$video_id]");
		return;
	}
	
	change_status($video_id, "delete");
	
	dbg("download successfully finished: $filename");
	my $new_path  = do {
		my $dl_dir = dir(config->{download_dir});
		-e $dl_dir or $dl_dir->mkpath;
		"$dl_dir/$title";
	};
	
	move $filename, encode_utf8($new_path);
	dbg("moved $filename -> $new_path");
}

sub download {
	my ($video_url, $args) = @_;
	my $filename;

	run_forked(
		"youtube-dl --audio-format mp3 --extract-audio '$video_url'", {
		stderr_handler => sub { err($_[0]) },
		stdout_handler => sub {
			#dbg($_[0]||"");
			given (shift) {
				when (/([\d\.]+)%/)              { $args->{on_progress}->($1) }
				when (/Destination: (.+\.mp3)$/) { $filename = $1; }
			}
		},
	});
	
	return $filename ? getcwd() . "/$filename" : undef;
}

sub change_status {
	my ($video_id, $mode, $args) = @_;
	my $title = encode_utf8($args->{title} || "");

	given ($mode) {
		local $SIG{__WARN__} = sub {
			err($_[0]) unless $_[0] ~~ /column (?:.+) is not unique/is;
		};
		when ("update") {
			try {
				model->insert('dl_status', {
					video_id   => $video_id,
					progress   => $args->{progress},
					created_at => time,
					updated_at => time,
					title      => $title,
				});
			} catch {
				err($_) unless $_ ~~ /column (?:.+) is not unique|^update$/is;
				
				try {
					model->update('dl_status', {
						progress   => $args->{progress},
						updated_at => time,
					}, {
						video_id   => $video_id,
					});
				} catch {
					err($_);
				};
			};
		}
		when ("delete") {
			model->delete('dl_status', {video_id => $video_id});
		}
	}
}

sub cleanup {
	model->delete('dl_status', {
		updated_at => {'<', time - 60 * 3},
	});

	for my $dat (zglob(getcwd() . '/*.{mp4,flv,part}')) {
		unlink $dat if (stat($dat))[10] < time - 60 * 3;
	}
}

sub get_title {
	my ($video_url) = @_;
	return decode_utf8(`youtube-dl --get-title '$video_url'`) . ".mp3";
}



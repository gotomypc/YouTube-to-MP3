#!perl
use 5.12.0;
use warnings;
use Path::Class;
use Amon2::Lite;
use lib file(__FILE__)->dir->subdir('lib')->stringify;
use YouTubeDL::Web;
use YouTubeDL::Util qw/truncate_mb/;
use YouTubeDL::Config;
use Plack::Builder;
use Encode;
use XML::Atom::Feed;
use utf8;

__PACKAGE__->load_plugins(qw/DBI/);
sub config {
	+{
		'DBI' => [ YouTubeDL::Config::config->{dns} ],
		'Text::Xslate' => +{
			function => {
				uri_for  => sub { Amon2->context()->uri_for(@_) },
				truncate_mb => sub {
					my @args = @_;
					return sub { truncate_mb(shift, @args) };
				},
				sprintf => sub {
					my $format = shift;
					return sub { sprintf($format, shift) };
				},
			},
		},
	}
}

get '/' => sub {
	my $c = shift;
	my $q	 = $c->req->param('q');
	my $page = $c->req->param('page') || 1;
	my $mode = $c->req->param('mode');

	my $limit = 20;
	my %opts = (limit => $limit, page => $page);
	
	my $rows;
	given ($mode) {
		when ('keyword') {
			$rows = $c->model->search_youtube(keyword => $q, %opts);
		}
		when ('artist') {
			$rows = $c->model->search_lastfm(artist => $q, %opts);
		}
	}
	return $c->render('index.tt', {
		q		  => $q,
		mode	  => $mode || 'keyword',
		rows	  => $rows,
		page	  => $page,
		next_page => scalar(@$rows) == $limit ? $page + 1 : undef,
		prev_page => $page > 1				  ? $page - 1 : undef,
	});
};

get '/status' => sub {
	my $c = shift;
	return $c->render('status.tt', {
		rows => $c->dbh->selectall_arrayref(q'SELECT * FROM dl_status', {Slice => +{}}),
	});
};

get '/enqueue' => sub {
	my ($c) = @_;
	my $video_id = $c->req->param('video_id');
	my $queue_file = file(__FILE__)->dir->file('.queue');
	`echo '$video_id' >> $queue_file`;
	$c->res_200;
};


builder {
	__PACKAGE__->to_app();
};

__DATA__

@@ index.tt
<!doctype html>
<html>
<head>
<meta charst="utf-8">
<title>downloader</title>
<script src="https://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js"></script>
<script>
function c(s){console.log(s)}
function a(s){alert(s)}
$(function(){
	var downloading = 0;
	$('input[type="text"]').focus();
	startUpdateStatus();
	function getLink(self) { return $(self).parent().attr('video-id') }
	$('.download').click(function(){
		$.get("/enqueue", { video_id: getLink(this) });
		if (!downloading) startUpdateStatus();
		$(this).addClass("downloading");
	});
	$('.play').click(function(){
		var videoId = getLink(this);
		$('#video-container').html('<object type="application/x-shockwave-flash" id="player" data="http://www.youtube.com/v/' + videoId + '?enablejsapi=1&amp;autoplay=1&amp;showinfo=1&amp;rel=0&amp;cc_load_policy=0&amp;iv_load_policy=3&amp;showsearch=0&amp;probably_logged_in=0&amp;fs=1" ><param name="allowScriptAccess" value="always"><param name="allowFullScreen" value="true"></object>');
	});
	$('tr:odd').addClass('even');

	var cnt = 0;
	//startUpdateStatus();
	function startUpdateStatus() {
		downloading = 1;
		c("=== downloading on ===");
		var tid = setInterval(function(){
			updateStatus(tid);
		}, 1000 * 2);
	}
	function updateStatus(tid) {
		$.get("/status", function(html){
			//if (/^\s*$/.test(html)) {
			//	if (++cnt >= 10) {
			//		clearInterval(tid);
			//		downloading = 0;
			//		c("=== downloading off ===");
			//	}
			//} else {
			//	cnt = 0;
				$('#queue').html(html);
			//}
		});
	}
});
</script>
</head>
<body>
	<div id="header">
		<div id="header-container">
			<h2>YouTube to MP3</h2>
			<form action="/" method="get">
				<input type="text" name="q" value="[% q %]""/>
				<label><input type="radio" name="mode" value="keyword" [% IF mode == 'keyword' %]checked[% END %]>Keyword</option></label>
				<label><input type="radio" name="mode" value="artist"  [% IF mode == 'artist'  %]checked[% END %]>Artist </option></label>
				<input type="submit" value="Search"/>
			</form>
		</div>
	</div>
	<div id="wrapper">
		<div id="debug">
		</div>
		<div id="main">
			[% IF rows.size() %]
				<table>
					[% FOR row IN rows %]
						<tr video-id="[% row.video_id %]">
							<td class="play">Play</td>
							<td class="download">MP3</td>
							<td class="title">[% row.title | truncate_mb(56) %]</td>
						</tr>
					[% END %]
				</table>
			[% END %]
			<div id="pager">
				[%	IF prev_page %]<a href="[% uri_for('/', {q => q, mode => mode, page => prev_page}) %]">< Prev</a> [% END -%]
				[%- IF next_page %]<a href="[% uri_for('/', {q => q, mode => mode, page => next_page}) %]"> Next ></a>[% END  %]
			</div>
		</div>
		<div id="sidebar">
			<div id="video-container">
			</div>
			<div id="queue">
				<p align="center">Queue</p>
			</div>
		</div>
	</div>
</body>
</html>

<style type="text/css">
/* * { outline: 1px dotted pink } */

#wrapper {
	width: 900px;
}

td {
	padding-left:  5px;
	padding-right: 5px;
}

/* ----- Header ----- */
body {
	margin: 0px;
}
td.play, td.download {
	color: white;
	text-decoration: none;
	background-color: #989C86;
	margin: 0px;
	padding: 2px;
	font-size: 80%;
	cursor: pointer;
}
td.downloading {
	background-color: white;
}
#header {
	color: white;
	background-color: #4C3535;
	margin: 0px 0px 15px 0px;
}
#header-container {
	margin-left : auto ; margin-right : auto ; width: 800px;
}
h2 {
	margin: 0px 10px;
	vertical-align: middle;
	display: inline;
}
form {
	vertical-align: middle;
	display: inline;
}
input[type="text"] {
	width: 150px;
	height: 18px;
	font-size: 100%;
}

/* ----- Main ----- */
#main {
	float: right;
	width: 590px;
}
tr.even {
	background-color: #ECECEC;
}
#pager a {
	color: #576B64;
	text-decoration: none;
}

/* ----- Sidebar ----- */
#sidebar {
	float: left;
	width: 290px;
	background-color: #FFEAC7;
}
#player {
	width:	280px;
	height: 200px;
}
.progress {
	font-weight: bold;
	text-align: left;
}
#video-container {
	width:	286px;
	height: 206px;
	padding: 3px;
}
#status {
	font-size: 80%;
}

</style>


@@ status.tt
[% IF rows.size() %]
	<table id="status">
		[% FOR row in rows %]
			<tr>
				<td class="progress">[% row.progress | sprintf("%0.1f") %]%</td>
				<td>[% row.title | truncate_mb(30) %]</td>
			</tr>
		[% END %]
	</table>
[% END%]

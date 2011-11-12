package YouTubeDL::Model;
use 5.10.0;
use warnings;
use URI;
use Encode;
use Net::LastFM;
use DBI;
use SQL::Abstract;
use parent qw/Exporter/;
use XML::Atom::Feed;
use Smart::Args;
use YouTubeDL::Config qw/config/;
use Class::Unload;
use Furl;
use Coro;

our @EXPORT_OK = qw/model/;

BEGIN {
	my $dbh = DBI->connect(config->{dns}, "", "", {AutoCommit => 1, RaiseError => 1});
	my $builder = SQL::Abstract->new();
	for my $method (qw/insert find search delete update/) {
		my $sub = sub {
			my $self = shift;
			
			given ($method) {
				when ("find") {
					my ($sql, @bind) = $builder->select(@_);
					return $dbh->selectrow_hashref($sql, undef, @bind) || {};
				}
				when ("search") {
					my ($sql, @bind) = $builder->select(@_);
					return $dbh->selectall_arrayref($sql, {Slice => +{}}, @bind);
				}
				default {
					my ($sql, @bind) = $builder->$method(@_);
					return $dbh->do($sql, undef, @bind);
				}
			}
		};
		
		no strict "refs";
		no warnings "redefine";

		*{__PACKAGE__ . "::$method"} = $sub;
	}
};

my $model_instance;
sub model { $model_instance //= bless {}, __PACKAGE__ }

# more info about YouTube API:
#	http://code.google.com/intl/ja/apis/youtube/developers_guide_protocol.html#Searching_for_Videos
my $furl;
sub search_youtube {
	args
		my $self,
		my $keyword  => 'Str',
		my $order_by => {isa => 'Str', default => 'relevance'},
		my $page     => {isa => 'Int', default => 1},
		my $limit    => {isa => 'Int', default => 20};
			
	my $uri = URI->new('http://gdata.youtube.com/feeds/api/videos');
	$uri->query_form(
		'vq'          => $keyword,
		'orderby'     => $order_by,
		'start-index' => ($page - 1) * 10 + 1,
		'max-results' => $limit,
	);

	my $feed = XML::Atom::Feed->new(Stream => do {
		$furl //= Furl->new();
		my $res = $furl->get($uri->as_string);
		return [] unless $res->is_success;
		\$res->content;
	});
	
	return [map {+{
		title    => decode_utf8($_->title),
		video_id => +{URI->new($_->link->href)->query_form}->{v},
	}} ($feed->entries)];
}

my $lastfm;
sub search_lastfm {
	args
		my $self,
		my $artist => 'Str',
		my $page   => {isa => 'Int', default => 1},
		my $limit  => {isa => 'Int', default => 20};

	$lastfm //= Net::LastFM->new(
		api_key    => config->{lastfm_api_key},
		api_secret => config->{lastfm_api_secret},
	);

	my $data;
	eval {
		$data = $lastfm->request_signed(
			method      => 'artist.getTopTracks',
			artist      => encode_utf8($artist),
			autocorrect => 1,
			page        => $page,
			limit       => $limit,
		);
	};

	warn $@ and return [] if $@;
	
	require Coro::LWP;
	my @coros;
	my @tracks;
   	for my $track (@{$data->{toptracks}->{track}}) {
   		push @coros, async {
			my $title = decode_utf8($track->{name});
			my $video = $self->search_youtube(
				keyword => "$artist $title",
				limit   => 1,
			);
			if ($video && $video->[0]) {
   				push @tracks, {
					listeners => $track->{listeners},
					%{$video->[0]},
				};
			}
   		};
   	}
   	$_->join for @coros;
	Class::Unload->unload('Coro::LWP');

   	return [sort {$b->{listeners} <=> $a->{listeners}} @tracks];
}

1;

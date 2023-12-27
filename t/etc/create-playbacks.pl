#!perl

use strict; use warnings;
use Mojo::UserAgent::Mockable;
use Config::JSON;
use File::Path qw|make_path|;

use lib 'lib';
use App::TelegramBot::RealTimeTrains;

my $bot = App::TelegramBot::RealTimeTrains->new(
    config => Config::JSON->new('config.json')
);

$bot->init;

$bot->rtt_ua( Mojo::UserAgent::Mockable->new( mode => 'record', file => 't/etc/playback.save' ) );
my $ua = $bot->rtt_ua;

my @samples = (
    'KGX/to/YRK/2024/02/06', # Kings Cross to York, midweek
    'XNP/to/YRK/2024/12/31', # North Pole, no services
    'KGX/to/YRK/2024/02/07', # Kings Cross to York again a day later
    'ABD/to/PNZ/2024/02/06', # Aberdeen to Penzance, 1 service per day
);

foreach ( @samples ) {
    my $url = $bot->rtt_url->clone;
    $url->path( "api/v1/json/search/$_" );
    $ua->get( $url );
}

use strict;
use warnings;
use Test2::V0 -target => 'App::TelegramBot::RealTimeTrains';

use DateTime;
use Test::MockDateTime;

use Mojo::UserAgent::Mockable;

my $mock_bot = mock 'App::TelegramBot::RealTimeTrains' => (
    track    => 1,
    override => [
        init  => sub {return},
    ]
);

subtest 'sanity check' => sub {
    isa_ok $CLASS->new( $CLASS, 'Telegram::Bot::Brain' );
};

my $bot = $CLASS->new();

$bot->rtt_ua( Mojo::UserAgent::Mockable->new(
    file => 't/etc/playback.save',
    mode => 'playback',
));
$bot->rtt_url( Mojo::URL->new('https://api.rtt.io/') );

subtest 'utilities' => sub {

    $bot->stations( Mojo::Collection->new(
        [ qw| SHF SHF Sheffield | ],
        [ qw| EDB EDB Edinburgh | ],
    ));

    subtest 'crs_decode' => sub {
        like $bot->_crs_to_name( 'SHF' ), qr/^Sheffield/, "Code lookup works";
        is $bot->_crs_to_name( 'XXX' ), 'XXX', "...and invalid codes just pass through";
    };

    subtest 'fetch services' => sub {
        my $trains;
        on '2024-02-06 12:34:56' => sub {
            $trains = $bot->_fetch_services( 'KGX', 'YRK', DateTime->now );
            is scalar @$trains, 44, "Found 44 services";
            is $trains->[0]->{destination}, 'Edinburgh', "Looks like we found the correct service";

            $trains = $bot->_fetch_services( 'XNP', 'YRK', DateTime->new( year => 2024, month => 12, day => 31 ) );
            is scalar @$trains, 0, "Found no trains from the North Pole";
        };
    }

};

done_testing();
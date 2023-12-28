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

my $mock_msg = mock 'Telegram::Bot::Object::Message' => (
    track => 1,
    override => [
        reply => sub {return shift;}
    ]
);

subtest 'sanity check' => sub {
    isa_ok $CLASS->new( $CLASS, 'Telegram::Bot::Brain' );
};


subtest 'utilities' => sub {

    my $bot = $CLASS->new();

    $bot->rtt_ua( Mojo::UserAgent::Mockable->new(
        file => 't/etc/playback.save',
        mode => 'playback',
    ));
    $bot->rtt_url( Mojo::URL->new('https://api.rtt.io/') );

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

subtest 'message handling' => sub {

    subtest 'dispatching' => sub {

        my %calls;
        $mock_bot->override(
            serviceinfo => sub {
                $calls{serviceinfo}++;
                return shift;
            },
            arrivals => sub {
                $calls{arrivals}++;
                return shift;
            },
            get_next_trains => sub {
                $calls{get_next_trains}++;
                return shift;
            },
            show_help => sub {
                $calls{show_help}++;
                return shift;
            }
        );

        my $bot = $CLASS->new();
        my $msg = Telegram::Bot::Object::Message->new();

        $bot->parse_request( $msg->text('something') );
        is $calls{get_next_trains}, 1, "Called get_next_trains when no specific command recognised";

        $bot->parse_request( $msg->text('/arrivals blah blah') );
        is $calls{arrivals}, 1, "Called arrivals method when required";

        $bot->parse_request( $msg->text('/serviceinfo') );
        is $calls{serviceinfo}, 1, "Called serviceinfo when required";

        $bot->parse_request( $msg->text('/help EDB to KGX') );
        is $calls{show_help}, 1, "Help command overrides rest of message";

        $bot->parse_request( $msg->text('foo /help bar') );
        is $calls{show_help}, 1, "Commands only activate at beginning of message";
        is $calls{get_next_trains}, 2, "...and thus we fall through to looking for services";

        $mock_bot->reset('serviceinfo');
        $mock_bot->reset('arrivals');
        $mock_bot->reset('get_next_trains');
        $mock_bot->reset('show_help');

    };

#    subtest 'get next trains' => sub {


#    };

#    subtest 'service lookup' => sub {

#    };

#    subtest 'help' => sub {

#    };

};

done_testing();
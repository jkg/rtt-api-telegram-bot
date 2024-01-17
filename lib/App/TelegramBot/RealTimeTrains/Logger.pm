package App::TelegramBot::RealTimeTrains::Logger;

use Log::Dispatch;
use Log::Dispatch::File;
use Log::Dispatch::Screen;

sub log_init {
    my $class = shift;
    my $bot = shift;

    my $logger = Log::Dispatch->new();

    $logger->add(
        Log::Dispatch::File->new(
            filename => $bot->config->get('logfile') // 'botlog',
            min_level => $bot->config->get('loglevel') // 'warning',
            name => 'mainlog',
        )
    );

    if ( defined $bot->config->get('debugmode') ) {
        $logger->add( 
            Log::Dispatch::Screen->new(
                name => 'debuglog',
                min_level => 'debug',
            )
        );
    }

    $bot->logger( $logger );
}

1;
package App::TelegramBot::RealTimeTrains::Logger;

use Log::Dispatch;

sub log_init {
    my $class = shift;
    my $bot = shift;

    my $logger = Log::Dispatch->new();

    $logger->add(
        Log::Dispatch::File->new(
            filename => $bot->config->get('logfile') // 'botlog',
            minlevel => $bot->config->get('loglevel') // 'warning',
            name => 'mainlog',
        )
    );

    if ( defined $bot->config->get('debugmode') ) {
        $logger->add( 
            Log::Dispatch::Screen->new(
                name => 'debuglog',
                minlevel => 'debug',
            )
        );
    }

    $bot->logger( $logger );
}

1;
package App::TelegramBot::RealTimeTrains;

#ABSTRACT: Simple Telegram bot that looks up UK train times / delays

use Mojo::Base 'Telegram::Bot::Brain';

use DateTime;
use Mojo::CSV;
use Try::Tiny;
use List::Util qw| first |;

use App::TelegramBot::RealTimeTrains::Logger;
use App::TelegramBot::RealTimeTrains::Schema;

has [
    qw| config token rtt_ua rtt_url stations logger schema |
];

sub init {
    my $self = shift;

    my $config = $self->config
        or $self->bail_out( "Can't initiate bot without a config, try again" );

    $self->token($config->get('botfather_token'))
        or $self->bail_out( "Can't initiate bot without a botfather token, update your config and try again" );

    my $creds = join ":", $config->get('rtt_username'), $config->get('rtt_token');

    my $url = Mojo::URL->new( 'https://' . $config->get('rtt_host') );
    $url->userinfo($creds);

    $self->rtt_url($url);
    $self->rtt_ua( Mojo::UserAgent->new );

    try {
        my $csv = Mojo::CSV->new( in => 'data/cif_tiplocs.csv' );
        $self->stations( $csv->slurp_body ) or die;
    } catch {
        $self->logger->warning( "Couldn't read station data; falling back to not using it" );
    };
    
    App::TelegramBot::RealTimeTrains::Logger->log_init( $self )
        unless defined $self->logger;

    unless ( $self->schema ) {
        try {
            $self->schema( App::TelegramBot::RealTimeTrains::Schema->connect( 'dbi:SQLite:bot.db' ) );
        } catch {
            $self->_bail_out( "Couldn't connect to database: $_" );
        };
    }

    $self->add_listener( \&parse_request );

    $self->add_repeating_task(
        $self->config->get('ratelimit_count_interval') // 60,
        \&_reduce_counters
    );
}

sub parse_request {

    my ( $self, $update ) = @_;
    
    try {
        if ( my $limit = $self->config->get('ratelimit_maximum')) {
            if ( $self->schema->resultset('User')->seen_user( $update->from->id ) > $limit ) {
                $self->logger->notice( "User ID " . $update->from->id . " was rate-limited" );
                $update->reply( "Cooldown in progress, please come back later" );
            }
        }
    } catch {
        $self->logger->debug( "Failed to do ratelimiting checks, continuing for now" );
    };

    my $text = $update->text or return;

    if ( $text =~ m[^/(start|help)\b] ) {
        return $self->show_help( $update );
    }

    if ( $text =~ m[^/arrivals\b] ) {
        return $self->arrivals( $update );
    }

    if ( $text =~ m[^/serviceinfo\b] ) {
        return $self->serviceinfo( $update );
    }

    $self->get_next_trains( $update );

}

sub get_next_trains {

    my $self = shift;
    my $update = shift;

    my $url = $self->rtt_url->clone;

    my ( $origin, $dest ) = $update->text =~ m|\b([A-Z]{3})\b.*\b([A-Z]{3})\b|i;
    $origin = uc $origin;
    $dest = uc $dest;

    unless ( defined $origin and defined $dest ) {
        $update->reply( "Sorry, I didn't recognise two stations there, you can ask me for /help if you need to." );
        return;
    }

    my @trains = $self->_fetch_services( $origin, $dest )->@*;

    if ( @trains < 4 ) {
        @trains = ( @trains, $self->_fetch_services( $origin, $dest, DateTime->now->add( days => 1 ) )->@* );
    }

    my @infoblocks;

    my $tomorrow = 0;

    for ( 0 .. 3 ) {
        my $train = shift @trains or last;

        my $text = "";
        unless ( $train->{is_today} or $tomorrow ) {
            $text .= "SERVICES TOMORROW:\n\n";
            $tomorrow = 1;
        }

        $text .= $train->{planned_departure} . " to " . $train->{destination};
        $text .= ( $train->{platform_changed} )
            ? ( $train->{platform} ) ? " at platform " . $train->{platform} . " (unplanned)" : ", possible platform change"
            : ( $train->{platform} ) ? " from platform " . $train->{platform} : "";
        $text .= "\n";


        if ( defined $train->{cancelled_message} ) {
                $text .= $train->{cancelled_message} . "\n";
                $text .= "Check link below or station information boards for more information\n";
        }
        
        {
            no warnings "uninitialized";
            $text .= 
                ( $train->{expected_arrival} > $train->{planned_arrival} or $train->{expected_departure} > $train->{planned_departure} )
                    ? "Expected in at " . $train->{expected_arrival} . " and out at " . $train->{expected_departure} . "\n"
                    : "Currently on time\n";
        }

        if ( defined $train->{expected_arrival_dest} ) {
            $text .= "ETA at $dest: " . $train->{expected_arrival_dest} 
                . ", planned as " . $train->{planned_arrival_dest}
                .  "\n";
        } else {
            $text .= "ETA at $dest: " . $train->{planned_arrival_dest} . "\n";
        }
        $text .= "This appears to be a " . $train->{vehicle} . "\n"
                unless $train->{vehicle} eq 'train';

        $text .= "https://www.realtimetrains.co.uk/service/gb-nr:" . $train->{uid} . "/" . $train->{run_date} . "\n";

        push @infoblocks, $text;
    }

    $origin = $self->_crs_to_name( $origin );
    $dest = $self->_crs_to_name( $dest );

    if ( @infoblocks ) {
        $update->reply( "I found the following services from $origin to $dest\n\n" . join "\n", @infoblocks );
    } else {
        $update->reply( "I didn't find any direct services between $origin and $dest today. I can only handle direct journeys, not multi-leg routing. See /help for more information." );
    }
}

sub show_help {

    my $self = shift;
    my $update = shift or return;

    my $help = <<'EOM';
This bot can help you to find the next few trains between points A and B, and whether they're currently delayed.

Just send the bot a message containing the three letter CRS codes for your start and end points, and it will attempt to find the next 4 direct services, today.

For example: 'KGX to YRK' will request upcoming services from Kings Cross to York.

The bot does not attempt to find routes involving changes; we recommend using a service like National Rail Enquiries or the ticketing staff at your local train station, for this.

For more information about the bot, see https://github.com/jkg/rtt-api-telegram-bot
EOM


    $update->reply( $help );


}

sub unimplemented {
    my $self = shift;
    my $update = shift or return;

    $update->reply( "Sorry, it looks like you've tried to use a command that hasn't been implemented yet! Check the /help for currently available functionality");
    return;
}

sub arrivals {
    shift->unimplemented;
}

sub serviceinfo {
    shift->unimplemented;
}

sub _crs_to_name {
    my $self = shift;
    my $code = uc(shift) or return;

    if ( my $record = $self->stations->first( sub{
        $_->[0] eq $code
    })) {
        return $record->[2];
    } else {
        return $code;
    }
}

sub _fetch_services {

    my ( $self, $origin, $dest, $dt ) = @_;

    if ( $origin and $dest ) {

        my $path = "/api/v1/json/search/$origin/to/$dest";

        if ( defined $dt ) {
            $path .= '/' . $dt->ymd('/');
        }

        my $url = $self->rtt_url;
        $url->path( $path );

        $self->logger->debug( $url );

        my $response = $self->rtt_ua->get( $url )->result;

        return () if $response->is_error;

        my @trains;
        my $data = $response->json;

        return [] unless defined $data->{services};

        for my $service ( $data->{services}->@* ) {

            my $serviceData = $self->_fetch_service_data( $service->{serviceUid}, $dt );

            next unless defined $serviceData->{locations};
            my @locations = $serviceData->{locations}->@*;

            my $call_from = first { defined $_->{crs} && $_->{crs} eq $origin } @locations;
            my $call_to = first { defined $_->{crs} && $_->{crs} eq $dest } @locations;

            my $cancelled_message;
            if ( defined $call_from->{cancelReasonCode} ) {
                $cancelled_message = "CANCELLED at/before $origin: " . $call_from->{cancelReasonShortText} // "Unknown Reason";
            } elsif ( $call_to->{cancelReasonCode} ) {
                my $last_stop = first { $_->{crs} and !defined $_->{cancelReasonCode} } @locations;
                if ( defined $last_stop ) { 
                    $cancelled_message = "CANCELLED after " . $self->_crs_to_name( $last_stop->{crs} ) . "\n";
                }
            }

            push @trains, {
                uid => $service->{serviceUid},
                origin => $service->{locationDetail}->{origin}->[0]->{description},
                destination => $service->{locationDetail}->{destination}->[0]->{description},
                vehicle => $service->{serviceType},
                planned_arrival => $service->{locationDetail}->{gbttBookedArrival},
                planned_departure => $service->{locationDetail}->{gbttBookedDeparture},  
                expected_arrival => $service->{locationDetail}->{realtimeArrival},
                expected_departure => $service->{locationDetail}->{realtimeDeparture},
                expected_arrival_dest => $call_to->{realTimeArrival},
                planned_arrival_dest => $call_to->{gbttBookedArrival},
                is_today => $service->{runDate} eq DateTime->now->ymd ? 1 : 0,
                run_date => $service->{runDate},
                cancelled_message => $cancelled_message,
                platform_changed => $call_from->{platformChanged},
                platform => $call_from->{platform},
            };

            last if @trains >= 4;
        }

        return \@trains;

    }

}

sub _fetch_service_data {

    my $self = shift;
    my $uid = shift;
    my $dt = shift // DateTime->now;

    my $path = "/api/v1/json/service/$uid/" . $dt->ymd('/');
 
    my $url = $self->rtt_url;
    $url->path( $path );
    $self->logger->debug( "$url\n" );
    
    my $response = $self->rtt_ua->get( $url )->result;

    return if $response->is_error;
    return $response->json;

}

sub _bail_out {
    my $self = shift;
    $self->logger->critical( shift );
    die;
}

sub _reduce_counters {
    my $self = shift;
    $self->schema->resultset('User')->reduce_counters( $self->config->get('ratelimit_count_value') );
}

1;

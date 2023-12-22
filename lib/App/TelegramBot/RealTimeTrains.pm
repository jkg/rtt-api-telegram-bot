package App::TelegramBot::RealTimeTrains;

use Mojo::Base 'Telegram::Bot::Brain';

use Try::Tiny;
use DateTime;

has [
    qw| config token rtt_ua rtt_url |
];

sub init {
    my $self = shift;

    my $config = $self->config
        or die "Can't initiate bot without a config, try again";

    $self->token($config->get('botfather_token'))
        or die  "Can't initiate bot without a botfather token, update your config and try again";

    my $creds = join ":", $config->get('rtt_username'), $config->get('rtt_token');

    my $url = Mojo::URL->new( 'https://' . $config->get('rtt_host') );
    $url->userinfo($creds);

    $self->rtt_url($url);
    $self->rtt_ua( Mojo::UserAgent->new );

    $self->add_listener( \&parse_request );
}

sub parse_request {

    my ( $self, $update ) = @_;
    my $text = $update->text or return;

    if ( $text =~ m[^/(start|help)\b] ) {
        return $self->show_help( $update );
    }

    if ( $text =~ m[^/arrivals\b] ) {
        return $self->unimplemented( $update );
    }

    if ( $text =~ m[^/serviceinfo\b] ) {
        return $self->unimplemented( $update );
    }

    $self->get_next_trains( $update );

}

sub get_next_trains {

    my $self = shift;
    my $update = shift;

    my $url = $self->rtt_url->clone;

    my ( $origin, $dest ) = $update->text =~ m|\b([A-Z]{3})\b.*\b([A-Z]{3})\b|;

    unless ( defined $origin and defined $dest ) {
        $update->reply( "Sorry, I didn't recognise two stations there, you can ask me for /help if you need to." );
        return;
    }

    $url->path( "/api/v1/json/search/$origin/to/$dest" );
    my $response = $self->rtt_ua->get( $url )->result;

    if ( $response->is_error ) {
        $update->reply( "API error, soz" );
        return;
    }

    my @trains;
    my $data = $response->json;
    for my $service ( $data->{services}->@* ) {
        push @trains, {
            uid => $service->{serviceUid},
            origin => $service->{locationDetail}->{origin}->[0]->{description},
            destination => $service->{locationDetail}->{destination}->[0]->{description},
            vehicle => $service->{serviceType},
            planned_arrival => $service->{locationDetail}->{gbttBookedArrival},
            planned_departure => $service->{locationDetail}->{gbttBookedDeparture},  
            expected_arrival => $service->{locationDetail}->{realtimeArrival},
            expected_departure => $service->{locationDetail}->{realtimeDeparture},
        };
    }

    @trains = sort { $a->{planned_departure} <=> $b->{planned_departure} } @trains;

    my @infoblocks;

    for ( 0 .. 3 ) {
        my $train = shift @trains or last;
        my $text = $train->{planned_departure} . " to " . $train->{destination} . "\n";

        {
            no warnings 'uninitialized';

            $text .= 
                ( $train->{expected_arrival} > $train->{planned_arrival} or $train->{expected_departure} > $train->{planned_departure} )
                    ? "Expected in at " . $train->{expected_arrival} . " and out at " . $train->{expected_departure} . "\n"
                    : "Currently on time\n";
        
            $text .= "This appears to be a " . $train->{vehicle} . "\n"
                unless $train->{vehicle} eq 'train';

        }

        $text .= "https://www.realtimetrains.co.uk/service/gb-nr:" . $train->{uid} . "/" . DateTime->now->ymd . "\n";

        push @infoblocks, $text;
    }

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
EOM


    $update->reply( $help );


}

sub unimplemented {
    my $self = shift;
    my $update = shift or return;

    $update->reply( "Sorry, it looks like you've tried to use a command that hasn't been implemented yet! Check the /help for currently available functionality");
    return;
}

1;

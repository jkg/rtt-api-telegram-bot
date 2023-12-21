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

    $self->add_listener( \&get_next_trains );
}

sub get_next_trains {

    warn "entered listener";

    my $self = shift;
    my $update = shift;

    my $url = $self->rtt_url->clone;

    my ( $origin, $dest ) = $update->text =~ m|\b([A-Z]{3})\b.*\b([A-Z]{3})\b|;

    unless ( defined $origin and defined $dest ) {
        $update->reply( "Sorry, I didn't recognise two stations there, I am looking for two three-letter CRS codes, like KGX or YRK" );
        return;
    }

    $url->path( "/api/v1/json/search/$origin/to/$dest" );

    my $response = $self->rtt_ua->get( $url )->result;

    warn "fetched URL " . $url;

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

        $text .= 
            ( $train->{expected_arrival} > $train->{planned_arrival} or $train->{expected_departure} > $train->{planned_departure} )
                ? "Expected in at " . $train->{expected_arrival} . " and out at " . $train->{expected_departure} . "\n"
                : "Currently on time\n";
        
        $text .= "This appears to be a " . $train->{vehicle} . "\n"
            unless $train->{vehicle} eq 'train';

        $text .= "https://www.realtimetrains.co.uk/service/gb-nr:" . $train->{uid} . "/" . DateTime->now->ymd . "\n";

        push @infoblocks, $text;
    }

    if ( @infoblocks ) {
        $update->reply( "I found the following services from $origin to $dest\n\n" . join "\n", @infoblocks );
    } else {
        $update->reply( "I didn't find any direct services between $origin and $dest. I only understand 3 letter CRS codes, not TIPLOCs, and I cannot help you route multi-leg journeys" );
    }
}

1;

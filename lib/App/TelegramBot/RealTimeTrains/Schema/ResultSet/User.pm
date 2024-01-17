package App::TelegramBot::RealTimeTrains::Schema::ResultSet::User;
 
use strict;
use warnings;
 
use base 'DBIx::Class::ResultSet';

sub seen_user {

    my $self = shift;
    my $tg_id = shift;
    my $user = $self->find_or_create({ telegram_id => $tg_id });

    $user->last_seen_epoch( DateTime->now->epoch );
    $user->activity_counter( $user->activity_counter + 1 );
    $user->update;

    return $user->activity_counter;
}

sub reduce_counters {

    my $self = shift;
    my $reduce_by = shift || 1;
    my $counted_users = $self->search_rs( { activity_counter => { '>', 0 } } );

    while ( my $user = $counted_users->next ) {
        $user->activity_counter( $user->activity_counter - $reduce_by );
        $user->update;
    }

}

1;

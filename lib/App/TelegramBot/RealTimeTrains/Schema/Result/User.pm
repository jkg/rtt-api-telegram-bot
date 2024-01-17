use utf8;
package App::TelegramBot::RealTimeTrains::Schema::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

App::TelegramBot::RealTimeTrains::Schema::Result::User

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<user>

=cut

__PACKAGE__->table("user");

=head1 ACCESSORS

=head2 telegram_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 last_seen_epoch

  data_type: 'integer'
  default_value: null
  is_nullable: 1

=head2 activity_counter

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "telegram_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "last_seen_epoch",
  { data_type => "integer", default_value => \"null", is_nullable => 1 },
  "activity_counter",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</telegram_id>

=back

=cut

__PACKAGE__->set_primary_key("telegram_id");


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2023-12-28 14:47:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:E4RhqlQicx5gVfg6qoj7jA

sub seen_user {
    my $self = shift;
    my $tg_id = shift;

    my $user_record = $self->schema->resultset('User')
        ->find_or_create( $tg_id );
    $user_record->last_seen_epoch( DateTime->now->epoch );
    return $user_record->activity_counter( $user_record->activity_counter + 1 );
}

sub reduce_counters {
    my $self = shift;


}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

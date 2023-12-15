#!perl

use strict;
use warnings;
use lib 'lib';

use Config::JSON ();
use App::TelegramBot::RealTimeTrains ();

my $config = Config::JSON->new('config.json');

App::TelegramBot::RealTimeTrains->new(
    config => $config,
)->think;



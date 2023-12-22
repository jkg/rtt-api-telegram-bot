# Realtime Trains TG Bot

## What is this?

It's a quick and dirty telegram bot which responds to a few simple commands
and looks up information about upcoming rail services on realtimetrains.co.uk
via their API.

It's only useful for UK trains and only if they're direct.

## How do I use it?

If you just want to find out when your next train is, speak to the bot via 
Telegram - there is an instance running as [https://t.me/UKTrainTimeBot](@UKTrainTimeBot).

If you want to run your own instance of it, you'll need to get an API key
from Realtime Trains, create a config.json file in the same directory
as this README file. The file looks like this:

```
{
    "botfather_token": "...",
    "rtt_host": "api.rtt.io",
    "rtt_username": "...",
    "rtt_token": "..."
}
```

## Where is the data from?

The csv file in the `data` directory is from [Rail Record](https://www.rail-record.co.uk/).

The data reported by the app comes from the (free) API provided by
[Realtime Trains](https://www.realtimetrains.co.uk).

## Can I contribute code / make a version for another platform

Yes! The code is available [on github](https://github.com/jkg/rtt-api-telegram-bot).

## This is really helpful, can I buy you a coffee?

I made this to scratch an itch I had - you don't need to do that. But if you
want to [buy me a coffee](https://ko-fi.com/jaykaygee) I won't say no!

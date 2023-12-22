# Realtime Trains TG Bot

## What is this?

It's a quick and dirty telegram bot which responds to a few simple commands
and looks up information about upcoming rail services on realtimetrains.co.uk
via their API.

It's only useful for UK trains and only if they're direct.

## How do I use it?

If you just want to find out when your next train is, speak to the bot via 
telegram - there is an instance running as @UKTrainTimeBot.

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


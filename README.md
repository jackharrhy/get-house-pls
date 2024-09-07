# get-house-please

## requires

- elixir >= 1.16
- telegram bot token

## setup

installs dependencies

```
mix deps.get
```

populate `./config/{env}/.secret.exs`:

```
import Config

config :house, :telegram_api_key, "1234:ABCD"
config :house, :telegram_chat_id, "987654321"

// if you inspect element on realtor.ca, and check out requests sent to
// https://api2.realtor.ca/Listing.svc/PropertySearch_Post
// you can figure out what the values you would like to use here are
config :house, :realtor_post_config,
  ZoomLevel: 14,
  LatitudeMax: 47.xxxxx,
  LongitudeMax: -52.xxxxx,
  LatitudeMin: 47.xxxxx,
  LongitudeMin: -52.xxxxx,
  PriceMax: 350_000

```

run the application

```
mix
```

TODO when the application runs the schedular isn't setup originally, only in prod, show how to run in prod

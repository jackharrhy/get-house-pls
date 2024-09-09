# get-house-please

## TODO

- supervisor tree seems broken, app does not start correctly... need to git bisect
- discord bot that posts in a thread

## development setup

### requires

- elixir >= 1.16
- telegram bot token

install dependencies:

```
mix deps.get
```

populate `.env`:

```
HOUSE_DATABASE=house.db
HOUSE_TELEGRAM_TOKEN=1234:ABCD
HOUSE_TELEGRAM_CHAT_ID=987654321
HOUSE_REALTOR_POST_CONFIG=ZoomLevel: 14, LatitudeMax: 47.xxxxx, LongitudeMax: -52.xxxxx, LatitudeMin: 47.xxxxx, LongitudeMin: -52.xxxxx, PriceMax: 350000
```

> if you inspect element on realtor.ca, and check out requests sent to
> https://api2.realtor.ca/Listing.svc/PropertySearch_Post
> you can figure out what the values you would like to use here are

run the application:

```
mix
```

**TODO when the application runs the schedular isn't setup originally, only in prod, show how to run in prod**

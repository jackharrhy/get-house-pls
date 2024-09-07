FROM hexpm/elixir:1.17.2-erlang-27.0.1-alpine-3.20.3 AS builder

RUN apk add --no-cache git

WORKDIR /app

COPY mix.exs mix.lock ./

ENV MIX_ENV=prod

RUN mix do deps.get, deps.compile

COPY lib ./lib
COPY config ./config

RUN mix do compile
RUN mix release

FROM hexpm/erlang:27.0.1-alpine-3.20.3

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/house ./

CMD ["./bin/house", "start"]

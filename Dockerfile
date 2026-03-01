FROM hexpm/elixir:1.17.3-erlang-27.2-debian-bookworm-20260223 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY mix.exs mix.lock ./

ENV MIX_ENV=prod

RUN mix do deps.get, deps.compile

COPY lib ./lib
COPY config ./config

RUN mix do compile
RUN mix release

FROM hexpm/erlang:27.2-debian-bookworm-20260223

WORKDIR /app

# Node.js 22.x (native WebSocket for our CDP script) + Google Chrome + Xvfb
#
# We install Google Chrome (not Debian's Chromium) because Incapsula's bot
# detection fingerprints the browser and rejects cookies from Chromium.
# Xvfb provides a virtual display so Chrome runs non-headless (headless mode
# is also fingerprinted and rejected).
#
# NOTE: Google Chrome is amd64-only. This image must be built on/for amd64.
# On Apple Silicon, build with: docker build --platform linux/amd64
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg wget \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
       | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
       > /etc/apt/sources.list.d/nodesource.list \
    && wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       nodejs \
       xvfb \
       fonts-freefont-ttf \
       fonts-noto-color-emoji \
    && apt-get install -y /tmp/chrome.deb \
    && rm /tmp/chrome.deb \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /tmp/chrome-realtor-cookies

ENV CHROME_BIN=/usr/bin/google-chrome-stable

COPY --from=builder /app/_build/prod/rel/house ./
COPY scripts ./scripts

CMD ["./bin/house", "start"]

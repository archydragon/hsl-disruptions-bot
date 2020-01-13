FROM elixir:1.9-alpine

WORKDIR /app

RUN mix local.hex --force \
    && mix local.rebar --force \
    && /root/.mix/rebar3 update

COPY mix.exs /app/mix.exs
COPY mix.lock /app/mix.lock
RUN mix deps.get \
    && mix deps.compile

COPY config /app/config
COPY lib /app/lib
RUN mix compile

CMD ["mix", "run", "--no-halt"]

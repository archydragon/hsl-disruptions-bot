use Mix.Config

config :hsl_disruptions_bot,
  messages_language: {:system, "MESSAGES_LANGUAGE", "en"}

config :slack,
  api_token: {:system, "SLACK_BOT_TOKEN"},
  channel_id: {:system, "SLACK_CHANNEL_ID"}

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :logger, :console,
  level: :info,
  format: "$date $time $metadata[$level] $levelpad$message\n"

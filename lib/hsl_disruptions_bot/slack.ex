defmodule HslDisruptionsBot.Slack do
  require Logger
  use GenServer

  # A function to allow external modules to send messages via Slack.
  def send_message(type, data) do
    GenServer.cast(__MODULE__, {:send, type, data})
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    Logger.info("Starting Slack client worker.")

    r = Slack.Web.Auth.test()

    if !r["ok"] do
      Logger.error("Slack auth test failed.")
      System.stop(0)
    end

    Logger.info("Connected to Slack team #{r["team"]} as #{r["user"]}.")

    {:ok, []}
  end

  def handle_cast({:send, type, data}, state) do
    Logger.debug("Received #{length(data)} entries of :#{type} type for sending through Slack.")

    channel_id = Application.get_env(:slack, :channel_id)

    Enum.each(data, fn d ->
      r =
        Slack.Web.Chat.post_message(channel_id, "", %{attachments: render_slack_message(type, d)})

      case r["ok"] do
        true ->
          Logger.debug("Slack message successfully sent, timestamp: #{r["ts"]}")

        false ->
          Logger.error("Failed to send Slack message.")
      end
    end)

    {:noreply, state}
  end

  # Render Slack message attachment for disruption information.
  defp render_slack_message(:disruption, ddata) do
    color =
      case ddata.severity do
        "INFO" -> "#3399ff"
        "WARNING" -> "#ffcc00"
        "SEVERE" -> "#cc0000"
        _ -> "#666666"
      end

    # Use default HSL web site URL if it is not mentioned in disruption info.
    url =
      case ddata.url do
        "" -> "https://www.hsl.fi/en"
        _ -> ddata.url
      end

    text = "#{ddata.description}\n\n#{url}"

    # Return JSON encoded string.
    Jason.encode!([%{color: color, text: text}])
  end

  # Render Slack message attachment for cancellation information.
  defp render_slack_message(:cancellation, cdata) do
    color =
      case cdata.state do
        "CANCELED" -> "#cc0000"
        "ADDED" -> "#00cc00"
        _ -> "#cc9900"
      end

    icon =
      case cdata.mode do
        "RAIL" -> ":bullettrain_side:"
        "BUS" -> ":bus:"
        "SUBWAY" -> ":metro:"
        "TRAM" -> ":tram:"
        _ -> ":question:"
      end

    # Departure time is provided by HSL API in seconds since midnight, convert it to minutes.
    time_minutes = div(cdata.departure_time, 60)

    # Format time to HH:MM format with leading zeroes.
    # Yep, it looks a bit creepy in Erlang/Elixir.
    time =
      "#{:io_lib.format("~2..0B", [div(time_minutes, 60)])}:#{
        :io_lib.format("~2..0B", [rem(time_minutes, 60)])
      }"

    text =
      "#{icon} #{String.capitalize(cdata.mode)} trip by the route" <>
        "*#{cdata.short_name}* (#{cdata.long_name}) at " <>
        "#{time} has been #{String.downcase(cdata.state)}."

    # Return JSON encoded string.
    Jason.encode!([%{color: color, text: text}])
  end
end

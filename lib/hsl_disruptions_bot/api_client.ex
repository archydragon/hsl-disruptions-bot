defmodule HslDisruptionsBot.APIClient do
  @moduledoc """
  Module to handle all GraphQL based communication with HSL API.
  Runs scheduled querying for ongoing disruptions + handles calls from other modules.
  """

  require Logger
  use GenServer
  alias HslDisruptionsBot.{Model, Processor}

  @hsl_api_url "https://api.digitransit.fi/routing/v1/routers/hsl/index/graphql"
  # Pause between queries in seconds.
  @querying_delay 60

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    Logger.info("Starting GraphQL API client worker.")

    # Configure GraphQL client.
    Neuron.Config.set(url: @hsl_api_url)
    Logger.debug("Using #{@hsl_api_url} API endpoint")
    # Initiate polling process.
    schedule([:get_disruptions, :get_cancellations])

    # Populate default state.
    lang = Application.get_env(:hsl_disruptions_bot, :messages_language)
    Logger.info("Using '#{lang}' as preferred language for received information.")
    state = %{lang: lang}

    {:ok, state}
  end

  def handle_info(:get_disruptions, state) do
    Logger.debug("Querying for ongoing disruptions.")

    query = """
    {
      alerts(feeds: ["HSL"]) {
        id
        alertSeverityLevel
        effectiveStartDate
        effectiveEndDate
        alertDescriptionTextTranslations {
          text
          language
        }
        alertUrlTranslations {
          text
          language
        }
      }
    }
    """

    api_query(query, fn response_body ->
      # Execute query, parse result, pass results to the processor.
      alerts = parse_alerts_response(response_body, state[:lang])
      Logger.debug("Received #{length(alerts)} alerts information, sending them for processing.")
      Processor.process_disruptions(alerts)
    end)

    # Schedule next execution.
    schedule([:get_disruptions])
    {:noreply, state}
  end

  def handle_info(:get_cancellations, state) do
    Logger.debug("Querying for ongoing cancellations.")

    # Get current date and time to filter trips which were already done but keep flickering.
    {:ok, datetime} = DateTime.now("Europe/Helsinki")

    date =
      datetime
      |> DateTime.to_date()
      |> Date.to_iso8601()

    time = datetime.hour * 3600 + datetime.minute * 60
    Logger.debug("Using date #{date} and time #{time}.")

    query = """
    {
      cancelledTripTimes(
        feeds: ["HSL"]
        minDate: "#{date}"
        minArrivalTime: #{time}
      ) {
        scheduledDeparture
        serviceDay
        trip {
          gtfsId
          pattern {
            name
          }
          route {
            gtfsId
            longName
            shortName
            mode
          }
        }
        realtimeState
        headsign
      }
    }
    """

    api_query(query, fn response_body ->
      # Execute query, parse result, pass results to the processor.
      cancellations = parse_cancelled_trips_response(response_body, state[:lang])

      Logger.debug(
        "Received #{length(cancellations)} cancellations information, sending them for processing."
      )

      Processor.process_cancellations(cancellations)
    end)

    # Schedule next execution.
    schedule([:get_cancellations])
    {:noreply, state}
  end

  def handle_info({:ssl_closed, _}, state) do
    Logger.debug("SSL session has been closed.")
    {:noreply, state}
  end

  # Helper to schedule queries execution.
  defp schedule([message | tail]) do
    delay = @querying_delay * 1000
    Logger.debug("Scheduling :#{message} to be sent in #{delay} ms")
    Process.send_after(self(), message, delay)
    schedule(tail)
  end

  defp schedule([]) do
  end

  # Helper to query GraphQL and process result.
  defp api_query(query, success_callback) do
    case Neuron.query(query) do
      {:ok, %Neuron.Response{body: response_body, status_code: 200}} ->
        success_callback.(response_body)

      {:ok, %Neuron.Response{body: response_body, status_code: code}} ->
        Logger.error("API returned HTTP status #{code}: #{inspect(response_body)}")
        []

      {:error, error} ->
        Logger.error("Error querying GraphQL API: #{inspect(error)}")
        []
    end
  end

  # Parse response from alerts (a.k.a. disruptions) endpoint.
  defp parse_alerts_response(nil, _) do
    []
  end

  defp parse_alerts_response(%{"data" => nil}, _) do
    []
  end

  defp parse_alerts_response(%{"data" => %{"alerts" => raw_alerts}}, lang) do
    Enum.map(raw_alerts, fn r ->
      struct(Model.Disruption, %{
        id: r["id"],
        severity: r["alertSeverityLevel"],
        start_date: r["effectiveStartDate"],
        end_date: r["effectiveEndDate"],
        description: get_local_string(r["alertDescriptionTextTranslations"], lang),
        url: get_local_string(r["alertUrlTranslations"], lang)
      })
    end)
  end

  defp parse_alerts_response(catchall, _) do
    Logger.debug("Received unsupported response: #{inspect(catchall)}")
    Logger.warn("Could not parse alerts response, maybe format has been changed.")
    []
  end

  # Parse response from cancelled trips endpoint.
  defp parse_cancelled_trips_response(nil, _) do
    []
  end

  defp parse_cancelled_trips_response(%{"data" => nil}, _) do
    []
  end

  defp parse_cancelled_trips_response(
         %{"data" => %{"cancelledTripTimes" => raw_cancellations}},
         _lang
       ) do
    Enum.map(raw_cancellations, fn r ->
      struct(Model.Cancellation, %{
        id: r["trip"]["gtfsId"],
        mode: r["trip"]["route"]["mode"],
        long_name: r["trip"]["route"]["longName"],
        short_name: r["trip"]["route"]["shortName"],
        pattern_name: r["trip"]["pattern"]["name"],
        state: r["realtimeState"],
        day: r["serviceDay"],
        departure_time: r["scheduledDeparture"]
      })
    end)
  end

  defp parse_cancelled_trips_response(catchall, _) do
    Logger.debug("Received unsupported response: #{inspect(catchall)}")
    Logger.warn("Could not parse cancelled trips response, maybe format has been changed.")
    []
  end

  # Helper function to get a string from the list of maps in proper language.
  # GraphQL data contains list of maps for 3 languages supported by HSL, we need only a string
  # in one of them.
  defp get_local_string(map, lang) do
    map
    |> Enum.map(fn t ->
      if t["language"] == lang do
        t["text"]
      end
    end)
    |> Enum.find(fn x -> x != nil end)
  end
end

defmodule HslDisruptionsBot.Processor do
  @moduledoc """
  Module to process incoming data and push forward if there are any interesting updates.
  """

  require Logger
  use GenServer
  alias HslDisruptionsBot.Slack

  # Function for external calls for sending data for processing.
  def process_disruptions(data) do
    GenServer.cast(__MODULE__, {:process_disruptions, data})
  end

  # Function for external calls for sending data for processing.
  def process_cancellations(data) do
    GenServer.cast(__MODULE__, {:process_cancellations, data})
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    Logger.info("Starting processing worker.")

    state = %{
      fresh_disruptions: true,
      known_disruptions: [],
      fresh_cancellations: true,
      known_cancellations: []
    }

    {:ok, state}
  end

  def handle_cast(
        {:process_disruptions, disruptions},
        %{:known_disruptions => known_disruptions} = state
      ) do
    Logger.debug("Processor received disruptions data.")

    # Don't push forward if current state is empty. It means that applications has just
    # started and doesn't have any data. We are interested only in new disruptions information.
    push_forward = !state[:fresh_disruptions]

    {new_disruptions, new_known_disruptions} =
      find_new_disruptions(known_disruptions, disruptions)

    if new_disruptions != [] && push_forward do
      Logger.info("Detected #{length(new_disruptions)} new disruptions.")
      Logger.debug("Those disruptions will be sent to Slack: #{inspect(new_disruptions)}")
      Slack.send_message(:disruption, new_disruptions)
    end

    {:noreply,
     %{state | :known_disruptions => new_known_disruptions, :fresh_disruptions => false}}
  end

  def handle_cast(
        {:process_cancellations, cancellations},
        %{:known_cancellations => known_cancellations} = state
      ) do
    Logger.debug("Processor received cancellations data.")

    # Don't push forward if current state is empty. It means that applications has just
    # started and doesn't have any data. We are interested only in new cancellations information.
    push_forward = !state[:fresh_cancellations]

    {new_cancellations, new_known_cancellations} =
      find_new_cancellations(known_cancellations, cancellations)

    if new_cancellations != [] && push_forward do
      Logger.info("Detected #{length(new_cancellations)} new cancellations.")
      Logger.debug("Those cancellations will be sent to Slack: #{inspect(new_cancellations)}")
      Slack.send_message(:cancellation, new_cancellations)
    end

    {:noreply,
     %{state | :known_cancellations => new_known_cancellations, :fresh_cancellations => false}}
  end

  defp find_new_disruptions(known_disruptions, disruptions_data) do
    # All disruptions have base64 encoded ID which starts from alert ID which is unique
    # for each disruption. So those IDs can be used as diff detector.
    new_known_disruptions =
      Map.new(disruptions_data, fn d ->
        [alert_id | _] = String.split(Base.decode64!(d.id), " ")
        {alert_id, d}
      end)

    # Find all disruption keys which weren't present in the old state.
    new_disruptions_keys =
      Enum.filter(Map.keys(new_known_disruptions), fn dkey ->
        !Enum.member?(known_disruptions, dkey)
      end)

    # Find actual disruption data for all new keys.
    new_disruptions =
      Enum.map(new_disruptions_keys, fn dkey ->
        new_known_disruptions[dkey]
      end)

    {new_disruptions, Map.keys(new_known_disruptions)}
  end

  defp find_new_cancellations(known_cancellations, cancellations_data) do
    new_known_cancellations =
      Map.new(cancellations_data, fn c ->
        {c.id, c}
      end)

    # Find all cancellations keys which weren't present in the old state.
    new_cancellations_keys =
      Enum.filter(Map.keys(new_known_cancellations), fn ckey ->
        !Enum.member?(known_cancellations, ckey)
      end)

    # Find actual cancellation data for all new keys.
    new_cancellations =
      Enum.map(new_cancellations_keys, fn ckey ->
        new_known_cancellations[ckey]
      end)

    {new_cancellations, Map.keys(new_known_cancellations)}
  end
end

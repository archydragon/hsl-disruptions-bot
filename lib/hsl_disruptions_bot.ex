defmodule HslDisruptionsBot do
  require Logger
  use Application

  def start(_type, _args) do
    Logger.info("Starting application.")
    Confex.resolve_env!(:hsl_disruptions_bot)
    Confex.resolve_env!(:slack)

    import Supervisor.Spec, warn: false

    children = [
      worker(HslDisruptionsBot.APIClient, []),
      worker(HslDisruptionsBot.Processor, []),
      worker(HslDisruptionsBot.Slack, [])
    ]

    opts = [strategy: :one_for_one, name: HslDisruptionsBot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

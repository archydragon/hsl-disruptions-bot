defmodule HslDisruptionsBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :hsl_disruptions_bot,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {HslDisruptionsBot, []}
    ]
  end

  defp deps do
    [
      # env based configuration
      {:confex, "~> 3.4.0"},
      # GraphQL client
      {:neuron, "~> 4.1.0"},
      # JSON library
      {:jason, "~> 1.1"},
      # Slack client library
      {:slack, "~> 0.19.0"}
    ]
  end
end

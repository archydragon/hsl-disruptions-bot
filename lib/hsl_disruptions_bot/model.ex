defmodule HslDisruptionsBot.Model do
  # Model for disruptions information.
  defmodule Disruption do
    defstruct id: nil,
              severity: nil,
              start_date: nil,
              end_date: nil,
              description: nil,
              url: nil
  end

  # Model for cancelled trip information.
  defmodule Cancellation do
    defstruct id: nil,
              mode: nil,
              long_name: nil,
              short_name: nil,
              state: nil,
              day: nil,
              departure_time: nil
  end
end

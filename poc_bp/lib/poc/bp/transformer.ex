defmodule POC.BP.Transformer do
  @moduledoc """
  Simulates CPU work on events.
  """
  use GenStage

  @impl true
  def init(%{wait_ms: wait}) do
    {:producer_consumer, %{wait_ms: wait}}
  end

  @impl true
  def handle_events(events, _from, state = %{wait_ms: wait}) do
    events =
      events
      |> Enum.map(fn x ->
        Process.sleep(wait)
        x
      end)

    {:noreply, events, state}
  end
end

defmodule POC.BP.Emitter do
  use GenStage

  @impl true
  def init(%{}) do
    {:producer_consumer, %{}}
  end

  @impl true
  def handle_events(events, _from, state) do
    {:noreply, events, state}
  end
end

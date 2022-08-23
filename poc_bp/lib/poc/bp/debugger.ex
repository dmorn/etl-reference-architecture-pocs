defmodule POC.BP.Debugger do
  use GenStage
  require Logger

  @impl true
  def init(_) do
    {:consumer, %{}}
  end

  @impl true
  def handle_events(events, from, state) do
    Logger.info(events_count: Enum.count(events), from: from)
    {:noreply, [], state}
  end
end

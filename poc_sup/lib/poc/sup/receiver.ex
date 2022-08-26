defmodule POC.SUP.Receiver do
  use GenStage, restart: :transient

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl true
  def init(%{checkpoint_agent: agent, id: id}) do
    Process.flag(:trap_exit, true)
    POC.SUP.Telemetry.execute(:stage, %{state: :up}, %{module: __MODULE__, id: id})

    seen = %{} = Agent.get(agent, fn state -> state end)

    {:consumer, %{agent: agent, seen: seen, id: id},
     subscribe_to: [POC.SUP.Miner, max_demand: 20, min_demand: 10]}
  end

  @impl true
  def handle_events(events, _from, state = %{seen: seen, id: id}) do
    events =
      events
      |> Enum.filter(fn x -> !Map.has_key?(seen, x.index) end)

    seen =
      Enum.reduce(events, seen, fn x, seen ->
        Map.put(seen, x.index, nil)
      end)

    POC.SUP.Telemetry.execute(:buffer, %{count: length(events)}, %{id: id})

    {:noreply, [], %{state | seen: seen}}
  end

  @impl true
  def terminate(reason, state = %{agent: agent, seen: seen, id: id}) do
    Agent.update(agent, fn _state -> seen end)

    POC.SUP.Telemetry.execute(:stage, %{state: :down}, %{
      module: __MODULE__,
      id: id,
      reason: reason
    })

    {:shutdown, state}
  end
end
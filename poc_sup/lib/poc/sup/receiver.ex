defmodule POC.SUP.Receiver do
  use GenStage, restart: :transient

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl true
  def init(args = %{checkpoint_agent: agent}) do
    Process.flag(:trap_exit, true)

    seen = Agent.get(agent, fn state -> state end)
    state = Map.merge(args, %{seen: seen})

    {:consumer, state}
  end

  @impl true
  def handle_events(events, _from, state = %{seen: seen, id: id}) do
    events =
      events
      |> Enum.filter(fn x -> !Map.has_key?(seen, x.sample) end)

    seen =
      Enum.reduce(events, seen, fn x, seen ->
        Map.put(seen, x.sample, nil)
      end)

    POC.SUP.Telemetry.execute(:buffer, %{count: length(events)}, %{id: id})

    {:noreply, [], %{state | seen: seen}}
  end

  @impl true
  def terminate(reason, state) do
    %{checkpoint_agent: agent, seen: seen, parent: parent, ref: ref, id: id} = state

    Agent.update(agent, fn _state -> seen end)

    POC.SUP.Telemetry.execute(:stage, %{state: :down}, %{
      module: __MODULE__,
      id: id,
      reason: reason
    })

    if reason == {:shutdown, :eof} do
      send(
        parent,
        {:done, ref,
         %{
           seen_count: map_size(seen)
         }}
      )
    end

    {:shutdown, state}
  end
end

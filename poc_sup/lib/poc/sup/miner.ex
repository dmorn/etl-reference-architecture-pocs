defmodule POC.SUP.Miner do
  use GenStage, restart: :transient

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(%{input_path: path, checkpoint_agent: agent, id: id}) do
    Process.flag(:trap_exit, true)
    POC.SUP.Telemetry.execute(:stage, %{state: :up}, %{module: __MODULE__, id: id})

    dev = File.open!(path, read_ahead: 5_000)
    checkpoint = %{} = Agent.get(agent, fn state -> state end)
    {:producer, %{stream: IO.stream(dev, :line), next: 0, checkpoint: checkpoint, id: id}}
  end

  @impl true
  def handle_demand(demand, state = %{stream: stream, next: next, checkpoint: checkpoint}) do
    {packets, next} =
      stream
      |> Stream.take(demand)
      |> Enum.map(&String.trim/1)
      |> Enum.with_index()
      |> Enum.map_reduce(next, fn {x, rel}, _ ->
        index = next + rel
        {%{index: index, sample: x}, index}
      end)

    # Remove packets that have already been emitted
    packets =
      packets
      |> Enum.filter(fn x -> !Map.has_key?(checkpoint, x.index) end)

    if length(packets) == 0 do
      GenStage.async_info(self(), {:terminate, :normal})
      {:noreply, [], state}
    end

    {:noreply, packets, %{state | next: next + 1}}
  end

  @impl true
  def handle_info({:terminate, reason}, state) do
    {:stop, reason, state}
  end

  @impl true
  def terminate(reason, state = %{id: id}) do
    POC.SUP.Telemetry.execute(:stage, %{state: :down}, %{
      module: __MODULE__,
      id: id,
      reason: reason
    })

    state
  end
end

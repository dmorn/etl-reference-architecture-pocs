defmodule POC.SUP.Miner do
  use GenStage, restart: :transient

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl true
  def init(%{input_path: path, checkpoint_agent: agent, id: id}) do
    Process.flag(:trap_exit, true)
    POC.SUP.Telemetry.execute(:stage, %{state: :up}, %{module: __MODULE__, id: id})

    dev = File.open!(path, read_ahead: 5_000)
    checkpoint = Agent.get(agent, fn state -> state end)

    stream =
      dev
      |> IO.stream(:line)
      |> Stream.map(&String.trim/1)
      |> Stream.map(fn x -> %{sample: x} end)
      |> Stream.filter(fn x -> !Map.has_key?(checkpoint, x.sample) end)

    {:producer, %{stream: stream, id: id}}
  end

  @impl true
  def handle_demand(demand, state = %{stream: stream}) do
    packets = Enum.take(stream, demand)

    if length(packets) == 0 do
      GenStage.async_info(self(), {:terminate, {:shutdown, :eof}})
      {:noreply, [], state}
    else
      {:noreply, packets, state}
    end
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

defmodule POC.SUP.CaosFilter do
  use GenStage, restart: :transient

  def start_link(%{crash_agent: agent, id: id}) do
    next =
      Agent.get_and_update(agent, fn
        [] -> {nil, []}
        [h | t] -> {h, t}
      end)

    GenStage.start_link(__MODULE__, %{id: id, crash_at: next}, name: __MODULE__)
  end

  @impl true
  def init(%{id: id, crash_at: n}) do
    Process.flag(:trap_exit, true)

    {:ok, sup} = Task.Supervisor.start_link()
    {:producer_consumer, %{id: id, crash_at: n, sup: sup}}
  end

  @impl true
  def handle_events(events, _from, state = %{crash_at: crash, sup: sup, id: id}) do
    events =
      sup
      |> Task.Supervisor.async_stream_nolink(
        events,
        fn x = %{sample: sample} ->
          %{x | sample: String.to_integer(sample) * 2}
        end,
        max_concurrency: 1,
        ordered: true
      )
      |> Enum.flat_map(fn
        {:ok, x} ->
          [x]

        {:exit, reason} ->
          # TODO: shall we ask for more items to the producer?
          POC.SUP.Telemetry.execute(:stage, %{state: :down}, %{
            module: __MODULE__.Task,
            id: id,
            reason: reason
          })

          []
      end)
      |> Enum.map(fn x = %{sample: sample} ->
        if crash != nil && sample >= crash do
          raise "CAOS FILTER CRASH"
        end

        x
      end)

    {:noreply, events, state}
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

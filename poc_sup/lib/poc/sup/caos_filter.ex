defmodule POC.SUP.CaosFilter do
  use GenStage, restart: :transient

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(%{id: id, crash_prob: prob}) when prob < 1 and prob >= 0 do
    Process.flag(:trap_exit, true)
    POC.SUP.Telemetry.execute(:stage, %{state: :up}, %{module: __MODULE__, id: id})

    nope = List.duplicate(true, trunc(prob * 100))
    yes = List.duplicate(false, trunc((1 - prob) * 100))
    space = Enum.concat(nope, yes)

    {:ok, sup} = Task.Supervisor.start_link()

    {:producer_consumer, %{id: id, crash_space: space, sup: sup}}
  end

  @impl true
  def handle_events(events, _from, state = %{crash_space: space, sup: sup, id: id}) do
    if Enum.random(space) do
      raise "CAOS FILTER CRASH"
    end

    events =
      sup
      |> Task.Supervisor.async_stream_nolink(
        events,
        fn x = %{sample: sample} ->
          POC.SUP.Telemetry.execute(:stage, %{state: :up}, %{
            module: __MODULE__.Task,
            id: id
          })

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

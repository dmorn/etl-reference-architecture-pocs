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

    {:producer_consumer, %{id: id, crash_space: space}}
  end

  @impl true
  def handle_events(events, _from, state = %{crash_space: space}) do
    if Enum.random(space) do
      raise "CAOS FILTER CRASH"
    end

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

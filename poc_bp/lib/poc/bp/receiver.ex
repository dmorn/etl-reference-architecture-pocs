defmodule POC.BP.Receiver do
  require Logger
  use GenStage

  def consume_events_loop(state = %{start_at: nil}) do
    consume_events_loop(%{state | start_at: Time.utc_now()})
  end

  def consume_events_loop(state) do
    {:events, events, ref, from} =
      receive do
        msg = {:events, _events, _ref, _from} -> msg
      end

    Enum.each(events, fn _x ->
      Process.sleep(state.wait_ms)
    end)

    POC.BP.Telemetry.handle_event(
      :buffer,
      %{monotonic_time: :erlang.monotonic_time(), count: -Enum.count(events)},
      %{id: state.id}
    )

    if state.sync do
      send(from, ref)
    end

    state = %{state | count: state.count + Enum.count(events)}
    done = state.count == state.max

    if done do
      stop_at = Time.utc_now()

      POC.BP.Telemetry.handle_event(
        :timing,
        %{elapsed_ms: Time.diff(stop_at, state.start_at, :millisecond)},
        %{id: state.id}
      )

      send(
        state.parent,
        {:done,
         %{
           start_at: state.start_at,
           stop_at: stop_at
         }}
      )
    else
      consume_events_loop(state)
    end
  end

  @impl true
  def init(%{
        wait_ms: wait,
        sync: sync,
        id: id,
        parent: parent,
        max: max
      }) do
    pid =
      spawn_link(__MODULE__, :consume_events_loop, [
        %{wait_ms: wait, sync: sync, start_at: nil, parent: parent, id: id, count: 0, max: max}
      ])

    {:consumer, %{sync: sync, consumer: pid, id: id}}
  end

  @impl true
  def handle_call(:inspect, _from, state), do: {:reply, state, [], state}

  @impl true
  def handle_events(events, _from, state = %{sync: sync, consumer: pid, id: id}) do
    POC.BP.Telemetry.handle_event(
      :buffer,
      %{monotonic_time: :erlang.monotonic_time(), count: Enum.count(events)},
      %{id: id}
    )

    ref = make_ref()

    send(pid, {:events, events, ref, self()})

    if sync do
      receive do
        ^ref -> :ok
      end
    end

    {:noreply, [], state}
  end
end

defmodule POC.SUP.Telemetry do
  @events [
    :buffer,
    :stage,
    :time
  ]

  def init(config = %{base_dir: dir}) do
    File.rm_rf(dir)
    File.mkdir_p(dir)

    {:ok, state} =
      Agent.start_link(fn ->
        path = Path.join(dir, "telemetry.jsonl")
        dev = File.open!(path, [:exclusive, :append])
        %{dev: dev, path: path}
      end)

    Enum.each(@events, fn id ->
      :telemetry.detach(id)
      :telemetry.attach(id, [id], &__MODULE__.handle_telemetry_event/4, state)
    end)

    {:ok, config}
  end

  def execute(event, measurement, meta) when event in @events do
    :telemetry.execute(
      [event],
      Map.put(measurement, :monotonic_time, :erlang.monotonic_time()),
      meta
    )
  end

  def handle_telemetry_event([:time], %{state: :in, monotonic_time: t}, %{id: id}, agent) do
    %{dev: dev} =
      Agent.get_and_update(agent, fn state ->
        state = Map.put_new(state, :t0, t)
        {state, state}
      end)

    %{
      "type" => "time-in",
      "t0" => Integer.to_string(:erlang.convert_time_unit(t, :native, :microsecond)),
      "id" => id
    }
    |> Jason.encode!()
    |> String.replace("\n", "", global: true)
    |> List.wrap()
    |> Kernel.++([",\n"])
    |> then(&IO.write(dev, &1))
  end

  def handle_telemetry_event(event, measurement, meta, agent) do
    Agent.update(agent, fn state ->
      case event do
        [:time] ->
          %{id: id} = meta
          %{monotonic_time: t} = measurement
          %{t0: t0, dev: dev} = state

          %{
            "type" => "time-out",
            "duration_ms" =>
              Integer.to_string(:erlang.convert_time_unit(t - t0, :native, :millisecond)),
            "id" => id
          }
          |> Jason.encode!()
          |> String.replace("\n", "", global: true)
          |> List.wrap()
          |> Kernel.++([",\n"])
          |> then(&IO.write(dev, &1))

        [:stage] ->
          %{state: stage_state, monotonic_time: t} = measurement
          update_stage(state, Map.merge(meta, %{state: stage_state, t: t}))

        [:buffer] ->
          %{count: count, monotonic_time: t} = measurement
          %{id: id} = meta
          update_buffer(state, %{id: id, count: count, t: t})
      end
    end)
  end

  defp update_stage(state, data) do
    base = %{
      "type" => "stage",
      "time_microsecond" =>
        Integer.to_string(:erlang.convert_time_unit(data.t - state.t0, :native, :microsecond)),
      "state" => Atom.to_string(data.state),
      "module" => inspect(data.module),
      "id" => data.id
    }

    payload =
      if data.state == :down do
        reason =
          case data.reason do
            {:shutdown, :eof} -> "EOF"
            {%RuntimeError{message: message}, _} -> message
            {:bad_return_value, {:stop, {%RuntimeError{message: message}, _}}} -> message
            other -> inspect(other)
          end

        Map.merge(base, %{reason: reason})
      else
        base
      end

    payload
    |> Jason.encode!()
    |> String.replace("\n", "", global: true)
    |> List.wrap()
    |> Kernel.++([",\n"])
    |> then(&IO.write(state.dev, &1))

    state
  end

  defp update_buffer(state, %{id: id, count: count, t: t}) do
    state = Map.update(state, :sum, count, fn old -> old + count end)

    %{
      "type" => "buffer",
      "time_microsecond" =>
        Integer.to_string(:erlang.convert_time_unit(t - state.t0, :native, :microsecond)),
      "sum" => Integer.to_string(state.sum),
      "id" => id
    }
    |> Jason.encode!()
    |> String.replace("\n", "", global: true)
    |> List.wrap()
    |> Kernel.++([",\n"])
    |> then(&IO.write(state.dev, &1))

    state
  end
end

defmodule POC.BP.Telemetry do
  alias VegaLite, as: Vl

  NimbleCSV.define(Parser, separator: ",")

  @events [
    :timing,
    :buffer
  ]

  def init(config = %{base_dir: dir}) do
    @events
    |> Enum.map(fn x ->
      path = Path.join(dir, Atom.to_string(x) <> ".csv")
      dev = File.open!(path, [:exclusive, :append])
      {:ok, agent} = Agent.start_link(fn -> %{dev: dev} end)

      {x, %{dev: dev, path: path, agent: agent}}
    end)
    |> Enum.each(fn {id, state} ->
      :telemetry.attach(id, [id], &__MODULE__.handle_telemetry_event/4, state)
    end)

    {:ok, config}
  end

  def handle_event(event, measurement, meta) when event in @events do
    :telemetry.execute([event], measurement, meta)
  end

  def handle_telemetry_event([:timing], %{elapsed_ms: ms}, %{id: id}, %{agent: agent}) do
    Agent.update(agent, fn state ->
      [
        Integer.to_string(ms),
        id
      ]
      |> Enum.intersperse(",")
      |> Kernel.++(["\n"])
      |> then(&IO.write(state.dev, &1))

      state
    end)
  end

  def handle_telemetry_event([:buffer], %{count: count, monotonic_time: t}, %{id: id}, %{
        agent: agent
      }) do
    Agent.update(agent, &update_track(&1, %{id: id, count: count, t: t}))
  end

  defp update_track(state, %{id: id, count: count, t: t}) do
    tracks = Map.get(state, :tracks, %{})

    track =
      tracks
      |> Map.get(id, %{t0: nil, sum: 0})
      |> Map.update!(:t0, fn
        nil -> t
        t -> t
      end)
      |> Map.update!(:sum, fn old -> old + count end)

    tracks = Map.put(tracks, id, track)
    state = Map.put(state, :tracks, tracks)

    [
      Integer.to_string(:erlang.convert_time_unit(t - track.t0, :native, :microsecond)),
      Integer.to_string(count),
      Integer.to_string(track.sum),
      id
    ]
    |> Enum.intersperse(",")
    |> Kernel.++(["\n"])
    |> then(&IO.write(state.dev, &1))

    state
  end

  def make_report(:buffer, dir) do
    path = Path.join(dir, "buffer.csv")
    output_path = Path.join(dir, "buffer.html")

    data =
      path
      |> File.stream!()
      |> Parser.parse_stream(skip_headers: false)
      |> Enum.map(fn [time, _count, sum, id] ->
        %{
          "time_microsecond" => String.to_integer(time),
          "sum" => String.to_integer(sum),
          "id" => id
        }
      end)

    Vl.new(width: 800, height: 400)
    |> Vl.data_from_values(data)
    |> Vl.mark(:line, filled: false)
    |> Vl.encode_field(:x, "time_microsecond",
      type: :quantitative,
      title: "time (microseconds)"
    )
    |> Vl.encode_field(:y, "sum",
      type: :quantitative,
      title: "samples produced + samples consumed"
    )
    |> Vl.encode_field(:color, "id", type: :nominal)
    |> Vl.Export.save!(output_path)
  end

  def make_report(:timing, dir, output_ext \\ ".html") do
    path = Path.join(dir, "timing.csv")
    output_path = Path.join(dir, "timing" <> output_ext)

    data =
      path
      |> File.stream!()
      |> Parser.parse_stream(skip_headers: false)
      |> Enum.map(fn [elapsed_ms, id] ->
        %{
          "elapsed_ms" => String.to_integer(elapsed_ms),
          "id" => id
        }
      end)

    Vl.new()
    |> Vl.data_from_values(data)
    |> Vl.mark(:bar, filled: true)
    |> Vl.encode_field(:x, "id",
      type: :nominal,
      title: "experiment identifier"
    )
    |> Vl.encode_field(:y, "elapsed_ms",
      type: :quantitative,
      title: "elapsed time (ms)"
    )
    |> Vl.Export.save!(output_path)
  end

  def make_reports(%{base_dir: dir}) do
    @events
    |> Enum.each(&make_report(&1, dir))
  end
end

# POC.BP Benchmark
defmodule Benchmark do
  def id(%{sync: sync, index: index, max_demand: max, min_demand: min, cc: cc}) do
    base =
    [
      "exp(#{index})",
      "-max(#{max})",
      "-min(#{min})",
      "-cc(#{cc})",
    ]

    if sync do
      base ++ ["+bp"] 
    else
      base
    end
  end

  def run(opts) do
    {:ok, d} = GenStage.start_link(POC.BP.Receiver, %{
      wait_ms: opts.wait_receiver,
      force: true,
      sync: opts.sync,
      id: id(opts),
      parent: self(),
      max: 5_000
    })
    {:ok, c} = GenStage.start_link(POC.BP.Emitter, %{})
    {:ok, a} = GenStage.start_link(POC.BP.Miner, %{
      input_path: "fake.dat"
    })

    filters =
      Range.new(1, opts.cc)
      |> Enum.map(fn _ ->
        {:ok, b} = GenStage.start_link(POC.BP.Transformer, %{
          wait_ms: opts.wait_transformer
        })                                                 
        b
      end)

    GenStage.sync_subscribe(d, to: c, max_demand: opts.max_demand, min_demand: opts.min_demand)
    Enum.each(filters, fn b ->
      GenStage.sync_subscribe(c, to: b, max_demand: opts.max_demand, min_demand: opts.min_demand)
    end)
    Enum.each(filters, fn b ->
      GenStage.sync_subscribe(b, to: a, max_demand: opts.max_demand, min_demand: opts.min_demand)
    end)

    timings = receive do
      {:done, data} -> data
    end

    timings
    |> Map.put(:elapsed_ms, Time.diff(timings.stop_at, timings.start_at, :millisecond))
    |> Map.merge(opts)
    |> Map.merge(%{id: id(opts)})
  end
end

require Logger

base_dir = "report"
File.rm_rf(base_dir)
File.mkdir_p(base_dir)

{:ok, telemetry} = POC.BP.Telemetry.init(%{base_dir: base_dir})

config_dev = File.open!(Path.join([base_dir, "config.txt"]), [:append])

experiments =
  Range.new(1, 10)
  |> Enum.map(fn x -> 2 ** x end)
  |> Enum.flat_map(fn max_demand ->
    [2, 4, 6, 8, 10, 16, 22, 28, 40, 80, 160, 320, 640, 1080]
    |> Enum.map(fn cc ->
      %{
        max_demand: max_demand,
        min_demand: trunc(max_demand / 2),
        wait_receiver: 1,
        wait_transformer: 10,
        sync: true,
        cc: cc
      }
    end)
  end)

results =
  experiments
  |> Stream.with_index()
  |> Stream.map(fn {x, index} -> Map.merge(x, %{index: index}) end)
  |> Stream.map(fn config ->
    Logger.info(%{exp: config})
    Benchmark.run(config)
  end)
  |> Stream.map(fn measurement ->
    Logger.info(%{result: measurement})
    IO.inspect(config_dev, measurement, [])
  end)
  |> Enum.to_list()

stats_dev = File.open!(Path.join([base_dir, "stats.txt"]), [:append])

Logger.info("generating statistics")
results
|> Enum.map(fn %{elapsed_ms: t} -> t end)
|> Statistex.statistics(percentiles: [25, 50, 75])
|> then(&IO.inspect(stats_dev, &1, []))

wait_ms = 5_000
Logger.info("waiting #{wait_ms/1_000}s for telemetry events to reach the disk")
Process.sleep(wait_ms)

Logger.info("making reports")
POC.BP.Telemetry.make_reports(telemetry)

Logger.info("reports stored at #{base_dir}")

defmodule Mix.Tasks.Benchmark do
  use Mix.Task
  import ExUnit.Assertions
  require Logger

  @requirements ["app.config"]
  @requirements ["app.start"]

  def run_pipeline(opts = %{ref: ref, id: id}) do
    Logger.info(opts)

    report_dir = Path.join(["report", id])

    {:ok, _telemetry} = POC.SUP.Telemetry.init(%{base_dir: report_dir})
    POC.SUP.Telemetry.execute(:time, %{state: :in}, %{id: id})

    {:ok, pid} = POC.SUP.Supervisor.start_link(opts)

    %{seen_count: seen} =
      receive do
        {:done, ^ref, data} -> data
      after
        15_000 ->
          raise "timeout reached on task #{inspect(ref)}, id #{inspect(id)}"
      end

    POC.SUP.Telemetry.execute(:time, %{state: :out}, %{id: id})

    Supervisor.stop(pid)

    %{
      experiment_id: opts.id,
      items_processed: seen,
      report_dir: report_dir,
      input_path: opts.input_path
    }
  end

  # special case
  def crash_points(n, _elements_count) when n <= 1, do: []

  def crash_points(n, elements_count) do
    step = elements_count / n
    Enum.map(Range.new(1, n - 1), fn x -> step * x end)
  end

  def usage() do
    "usage: <id> <number of crash points>"
  end

  @impl true
  def run([id, crashes | _rest]) do
    if id == "" do
      raise usage()
    end

    crashes = String.to_integer(crashes)

    if crashes < 0 do
      raise usage()
    end

    input_path = "num.short.dat"

    expected_count =
      input_path
      |> File.stream!()
      |> Stream.filter(fn x -> Integer.parse(x) != :error end)
      |> Enum.count()

    opts = %{
      id: id <> "-#{crashes}",
      parent: self(),
      input_path: input_path,
      ref: make_ref(),
      crash_points: crash_points(crashes, expected_count),
      max_demand: 80,
      min_demand: 40
    }

    result = run_pipeline(opts)
    assert result.items_processed == expected_count
    Logger.info(result)
  end
end

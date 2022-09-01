defmodule Mix.Tasks.Benchmark do
  use Mix.Task
  import ExUnit.Assertions
  require Logger

  @requirements ["app.config"]
  @requirements ["app.start"]

  @impl true
  def run(args) do
    id = Enum.join(args, "-")

    if id == "" do
      raise "provide an identifier when executing this task"
    end

    input_path = "num.short.dat"
    crash_prob = 0.01
    ref = make_ref()

    expected_count =
      input_path
      |> File.stream!()
      |> Stream.filter(fn x -> Integer.parse(x) != :error end)
      |> Enum.count()

    opts = %{
      id: id,
      parent: self(),
      input_path: input_path,
      ref: ref,
      crash_prob: crash_prob,
      max_demand: 80,
      min_demand: 40
    }

    {:ok, pid} = POC.SUP.Supervisor.start_link(opts)

    %{report_dir: dir, seen_count: seen} =
      receive do
        {:done, ^ref, data} -> data
      after
        15_000 ->
          raise "timeout reached on task #{inspect(ref)}, id #{inspect(id)}"
      end

    assert seen == expected_count

    Supervisor.stop(pid)

    Logger.info(%{
      experiment_id: id,
      items_processed: seen,
      report_dir: dir,
      input_path: input_path
    })
  end
end

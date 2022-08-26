defmodule POC.SUP.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(args) do
    %{id: id} = args
    report_dir = Path.join(["report", id])

    {:ok, _telemetry} = POC.SUP.Telemetry.init(%{base_dir: report_dir})
    {:ok, agent} = Agent.start_link(fn -> %{} end)

    args = Map.merge(args, %{checkpoint_agent: agent, report_dir: report_dir})

    children = [
      {POC.SUP.Pipeline, args}
    ]

    opts = [strategy: :one_for_one, max_restarts: 1_000, name: POC.SUP.Supervisor]
    Supervisor.init(children, opts)
  end
end

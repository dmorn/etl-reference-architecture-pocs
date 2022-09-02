defmodule POC.SUP.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(args) do
    {:ok, agent} = Agent.start_link(fn -> %{} end)
    {:ok, crash_agent} = Agent.start_link(fn -> args.crash_points end)

    args = Map.merge(args, %{checkpoint_agent: agent, crash_agent: crash_agent})

    children = [
      {POC.SUP.Pipeline, args}
    ]

    opts = [strategy: :one_for_one, max_restarts: 1_000, name: POC.SUP.Supervisor]
    Supervisor.init(children, opts)
  end
end

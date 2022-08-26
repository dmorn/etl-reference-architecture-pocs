defmodule POC.SUP.Supervisor do
  use Supervisor
  require Logger

  def start_link([]) do
    t = :erlang.convert_time_unit(:erlang.system_time(), :native, :millisecond)
    id = "poc-#{t}"
    start_link(id)
  end

  def start_link(id) when is_binary(id) do
    Supervisor.start_link(__MODULE__, %{id: id})
  end

  @impl true
  def init(%{id: id}) do
    report_dir = Path.join(["report", id])
    Logger.info(id: id, report_dir: report_dir)

    {:ok, _telemetry} = POC.SUP.Telemetry.init(%{base_dir: report_dir})
    {:ok, agent} = Agent.start_link(fn -> %{} end)

    children = [
      {POC.SUP.Miner, %{checkpoint_agent: agent, input_path: "fake.dat", id: id}},
      {POC.SUP.Receiver, %{checkpoint_agent: agent, id: id}}
    ]

    opts = [strategy: :one_for_one, name: POC.SUP.Supervisor]
    Supervisor.init(children, opts)
  end
end

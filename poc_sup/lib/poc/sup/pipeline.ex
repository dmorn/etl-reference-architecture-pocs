defmodule POC.SUP.Pipeline do
  use GenServer, restart: :transient

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(params) do
    Process.flag(:trap_exit, true)

    {:ok, a} = POC.SUP.Miner.start_link(params)
    {:ok, b} = POC.SUP.CaosFilter.start_link(params)
    {:ok, c} = POC.SUP.Receiver.start_link(params)

    GenStage.sync_subscribe(c, to: b, max_demand: params.max_demand, min_demand: params.min_demand)

    GenStage.sync_subscribe(b, to: a, max_demand: params.max_demand, min_demand: params.min_demand)

    {:ok, [a, b, c]}
  end

  @impl true
  def handle_info({:EXIT, from, {:shutdown, :eof}}, children) do
    children = Enum.filter(children, fn x -> x != from end)

    if children == [] do
      # when all children have exited, it is time for us too.
      {:stop, {:shutdown, :eof}, []}
    else
      # wait for the other exit messages to come, they are propagated from
      # miner to receiver caused by their subscription link.
      {:noreply, children}
    end
  end

  def handle_info({:EXIT, _from, reason}, _children) do
    # Childrens are linked to this process and will exit when we do.
    {:stop, reason}
  end
end

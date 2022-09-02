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

    %{max_demand: max, min_demand: min} = params

    GenStage.sync_subscribe(c, to: b, max_demand: max, min_demand: min)
    GenStage.sync_subscribe(b, to: a, max_demand: max, min_demand: min)

    {:ok, %{children: [a, b, c], id: params.id}}
  end

  @impl true
  def handle_info({:EXIT, from, {:shutdown, :eof}}, state = %{children: children}) do
    children = Enum.filter(children, fn x -> x != from end)

    if children == [] do
      # when all children have exited, it is time for us too.
      {:stop, {:shutdown, :eof}, %{state | children: []}}
    else
      # wait for the other exit messages to come, they are propagated from
      # miner to receiver caused by their subscription link.
      {:noreply, %{state | children: children}}
    end
  end

  def handle_info({:EXIT, _from, reason}, _children) do
    # Childrens are linked to this process and will exit when we do.
    {:stop, reason}
  end
end

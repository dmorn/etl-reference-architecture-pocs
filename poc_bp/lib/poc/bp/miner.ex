defmodule POC.BP.Miner do
  @doc """
  Provides data from a file.
  """

  use GenStage

  @impl true
  def init(%{input_path: path}) do
    dev = File.open!(path, read_ahead: 5_000)
    {:producer, %{stream: IO.stream(dev, :line), next: 0}}
  end

  @impl true
  def handle_demand(demand, state = %{stream: stream, next: next}) do
    {packets, next} =
      stream
      |> Stream.take(demand)
      |> Enum.map(&String.trim/1)
      |> Enum.with_index()
      |> Enum.map_reduce(next, fn {x, rel}, _ ->
        index = next + rel
        {%{index: index, sample: x}, index}
      end)

    if length(packets) == 0 do
      GenStage.async_info(self(), {:terminate, :normal})
      {:noreply, [], state}
    else
      {:noreply, packets, %{state | next: next + 1}}
    end
  end

  @impl true
  def handle_info({:terminate, reason}, state) do
    {:stop, reason, state}
  end
end

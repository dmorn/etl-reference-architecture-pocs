defmodule POC.BP.HashingTransformer do
  @moduledoc """
  Simulates CPU work on events.
  """
  use GenStage

  @impl true
  def init(%{repeat: count}) do
    {:producer_consumer, %{repeat: count}}
  end

  def process_sample(x, repeat) when repeat <= 0, do: x

  def process_sample(x, repeat) do
    :sha512
    |> :crypto.hash(x)
    |> Base.encode16(case: :lower)
    |> process_sample(repeat - 1)
  end

  @impl true
  def handle_events(events, _from, state = %{repeat: repeat}) do
    events =
      events
      |> Enum.map(fn x = %{sample: sample} ->
        # repeat=2000 makes process_sample last 6ms on my
        # computer. Use benchmark/process_sample.exs script to
        # understand which variable you want here based on your
        # computer.
        %{x | sample: process_sample(sample, repeat)}
      end)

    {:noreply, events, state}
  end
end


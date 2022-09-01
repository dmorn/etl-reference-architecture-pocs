defmodule POC.SUP.CoasFilterTest do
  use ExUnit.Case

  test "handle_events" do
    {:ok, sup} = Task.Supervisor.start_link()

    assert {:noreply, [%{sample: 4}], _} =
             [
               %{sample: "2"},
               %{sample: "a"}
             ]
             |> POC.SUP.CaosFilter.handle_events(nil, %{
               crash_space: [false],
               sup: sup,
               id: "test"
             })
  end
end

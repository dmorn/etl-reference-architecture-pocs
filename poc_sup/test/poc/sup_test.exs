defmodule POC.SUPTest do
  use ExUnit.Case
  doctest POC.SUP

  test "greets the world" do
    assert POC.SUP.hello() == :world
  end
end

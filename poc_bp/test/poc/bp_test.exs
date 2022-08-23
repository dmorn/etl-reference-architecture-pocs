defmodule POC.BPTest do
  use ExUnit.Case
  doctest POC.BP

  test "greets the world" do
    assert POC.BP.hello() == :world
  end
end

defmodule ChamexTest do
  use ExUnit.Case
  doctest Chamex

  test "greets the world" do
    assert Chamex.hello() == :world
  end
end

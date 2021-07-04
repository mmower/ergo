defmodule ErgoTest do
  use ExUnit.Case
  doctest Ergo

  test "greets the world" do
    assert Ergo.hello() == :world
  end
end

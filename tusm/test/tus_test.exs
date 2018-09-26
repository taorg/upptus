defmodule TusTest do
  use ExUnit.Case
  doctest Tus

  test "greets the world" do
    assert Tus.hello() == :world
  end
end

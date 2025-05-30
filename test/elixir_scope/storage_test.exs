defmodule ElixirScope.StorageTest do
  use ExUnit.Case
  doctest ElixirScope.Storage

  test "greets the world" do
    assert ElixirScope.Storage.hello() == :world
  end
end

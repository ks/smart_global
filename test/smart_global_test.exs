defmodule SmartGlobalTest do
  use ExUnit.Case
  doctest SmartGlobal

  test "greets the world" do
    assert SmartGlobal.hello() == :world
  end
end

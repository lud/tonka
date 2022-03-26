defmodule Tonka.CleanupHashTest do
  use ExUnit.Case, async: true
  alias Tonka.Services.CleanupStore
  alias Tonka.Services.CleanupStore.CleanupParams

  test "the raw key is used without if not param says otherwise" do
    key = "a_topic"
    module = __MODULE__
    params = CleanupParams.new(key: key)
    inputs = %{some: "input"}

    assert "a_topic" = CleanupStore.compute_key(module, params, inputs)
  end

  test "the given input names in params are used to build the key"

  test "if a given input name does not exist, it will fail"
end

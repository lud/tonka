defmodule Tonka.CleanupHashTest do
  use ExUnit.Case, async: true
  alias Tonka.Services.CleanupStore
  alias Tonka.Services.CleanupStore.CleanupParams

  test "the raw key is used without if not param says otherwise" do
    key = "a_topic"
    module = __MODULE__
    params = CleanupParams.new(key: key)
    inputs = %{some: "input"}

    assert "Tonka.CleanupHashTest::a_topic::" <> _ =
             CleanupStore.compute_key(module, params, inputs)
  end

  test "the ttl does not change the key" do
    key = "a_topic"
    module = __MODULE__
    params1 = CleanupParams.of(key: key)
    params2 = CleanupParams.of(key: key, ttl: 100)
    params3 = CleanupParams.of(key: key, ttl: 9999)
    inputs = %{some: "input"}

    assert p1 = CleanupStore.compute_key(module, params1, inputs)
    assert p2 = CleanupStore.compute_key(module, params2, inputs)
    assert p3 = CleanupStore.compute_key(module, params3, inputs)
    assert p1 == p2
    assert p1 == p3
  end

  defmodule Something do
    defstruct a: 1, b: {:ok, :cool}, c: 99.99

    defimpl Tonka.Services.CleanupStore.Hashable do
      # this does not actually support bitstrings, only binaries
      def hashable(something) do
        something
        |> Map.from_struct()
        |> Tonka.Services.CleanupStore.Hashable.hashable()
      end
    end
  end

  test "the given input names in params are used to build the key" do
    key = "a_topic"
    module = __MODULE__
    params_no_input = CleanupParams.of(key: key)
    params_empty_input = CleanupParams.of(key: key, inputs: [])
    params_some = CleanupParams.of(key: key, inputs: [:some])
    params_some_dupli = CleanupParams.of(key: key, inputs: [:some, :some])
    params_some_str = CleanupParams.of(key: key, inputs: ["some"])
    params_other = CleanupParams.of(key: key, inputs: [:other])
    params_both = CleanupParams.of(key: key, inputs: [:some, :other])
    params_both_rev = CleanupParams.of(key: key, inputs: [:other, :some])

    inputs = %{some: ["thing"], other: %Something{}}

    get_key = fn params ->
      key = CleanupStore.compute_key(module, params, inputs)
      assert is_binary(key)
      key
    end

    assert_all_different([
      get_key.(params_no_input),
      get_key.(params_some),
      get_key.(params_other),
      get_key.(params_both)
    ])

    assert get_key.(params_no_input) == get_key.(params_empty_input)
    assert get_key.(params_some) == get_key.(params_some_dupli)
    # using string input does not work thanks to a feature of the store but
    # thanks to the casting of the params structs
    assert get_key.(params_some) == get_key.(params_some_str)
    assert get_key.(params_both) == get_key.(params_both_rev)
  end

  defp assert_all_different(things) do
    things = Enum.with_index(things)

    for {v, i} <- things, {w, j} <- things, i != j do
      assert v != w
    end
  end

  test "if a given input name does not exist, it will fail"
end

defmodule Tonka.MQLTest do
  use ExUnit.Case, async: true
  alias Tonka.Core.Query.MQL

  test "yaml is compiled with atom keys" do
    assert {:compiled, _yaml, %{a: "val"}} = all_atoms_query("a: val")
  end

  test "atoms values should not be transformed by YamlElixir" do
    """
    a: :tom
    """
    |> assert_match(%{a: ":tom"})
    |> refute_match(%{a: :tom})
  end

  test "match an array of values" do
    """
    v: val
    """
    |> assert_match(%{v: "val"})
    |> assert_match(%{v: ["val"]})
    |> assert_match(%{v: ["some", "val"]})
    |> assert_match(%{v: ["val", "here"]})
    |> refute_match(%{a: []})
  end

  test "match a number" do
    """
    i: -10
    """
    |> assert_match(%{i: -10})
    |> refute_match(%{i: "-10"})

    """
    i: 1.001
    """
    |> assert_match(%{i: 1.001})
    |> refute_match(%{i: "1.001"})
  end

  test "compare equal between float and integer" do
    # Direct value will not match
    """
    n: 1
    """
    |> refute_match(%{n: 1.0})

    # $eq operator will compare equal
    """
    n: { $eq: 1 }
    """
    |> assert_match(%{n: 1.0})

    """
    n: 1.0
    """
    |> refute_match(%{n: 1})

    """
    n: { $eq: 1.0 }
    """
    |> assert_match(%{n: 1})

    # of course $eq will fail with different values of the same type
    """
    n: { $eq: 1.0 }
    """
    |> refute_match(%{n: 2.0})
  end

  test "match an existing key with nil" do
    # Searching for a nil value with $eq will only find maps that DO have the
    # key AND have a `nil` value associated with the key.
    """
    j: { $eq: ~ }
    """
    |> assert_match(%{j: nil})
  end

  test "match an existing key with nil, or a missing key" do
    # Searching directly for `nil` will return all objects that DO NOT have the
    # key OR have the key with a `nil` value associated to it.
    """
    j: ~
    """
    |> assert_match(%{j: nil})
    |> assert_match(%{})
    |> refute_match([])
    |> refute_match({:a, :tuple})
    |> refute_match(:atom)
    |> refute_match("bin")
  end

  test "match with $in" do
    """
    i: { $in: [0, 1] }
    """
    |> assert_match(%{i: 1})
    |> assert_match(%{i: 0})
    |> refute_match(%{i: 2})
  end

  test "match with an empty $in" do
    """
    i: { $in: [] }
    """
    |> refute_match(%{i: 1})
    |> refute_match(%{i: []})
    |> refute_match(%{})
  end

  test "match with $in against a list" do
    """
    ns: { $in: [0, 1] }
    """
    |> assert_match(%{ns: [0]})
    |> assert_match(%{ns: [1]})
    |> assert_match(%{ns: [0, 1]})
    |> assert_match(%{ns: [1, 9999]})
    |> assert_match(%{ns: [0, 9999]})
    |> refute_match(%{ns: []})
    |> refute_match(%{ns: [9999, 8888]})
  end

  test "match with $nin" do
    """
    i: { $nin: [0, 1] }
    """
    |> refute_match(%{i: 1})
    |> refute_match(%{i: 0})
    |> assert_match(%{i: 2})
  end

  test "match with $nin against a list" do
    """
    ns: { $nin: [0, 1] }
    """
    |> refute_match(%{ns: [0]})
    |> refute_match(%{ns: [1]})
    |> refute_match(%{ns: [0, 1]})
    |> refute_match(%{ns: [1, 9999]})
    |> refute_match(%{ns: [0, 9999]})
    |> assert_match(%{ns: []})
    |> assert_match(%{ns: [9999, 8888]})
  end

  test "test $or on the same key using a list of matches" do
    """
    $or:
        - name: alice
        - name: bob
    """
    |> assert_match(%{name: "alice"})
    |> assert_match(%{name: "bob"})
    |> refute_match(%{name: "carol"})
  end

  test "match with $and on two different keys in a query sub-map" do
    """
    $and:
        kind: "fruit"
        price: 10
    """
    |> assert_match(%{kind: "fruit", price: 10})
    |> refute_match(%{kind: "other", price: 10})
    |> refute_match(%{kind: "fruit", price: 9999})
  end

  test "match with $and on two different keys in a query list" do
    """
    $and:
        - kind: fruit
        - price: 10
    """
    |> assert_match(%{kind: "fruit", price: 10})
    |> refute_match(%{kind: "other", price: 10})
    |> refute_match(%{kind: "fruit", price: 9999})
  end

  test "match with $size" do
    """
    list:
      $size: 1
    """
    |> assert_match(%{list: [1]})
    |> refute_match(%{list: []})
    |> refute_match(%{list: [0, 1]})
    |> refute_match(%{list: "hello"})
    |> refute_match(%{})

    """
    list:
      $size: 1
    """
    |> assert_match(%{list: %{a: 1}})
    |> refute_match(%{list: %{}})
    |> refute_match(%{list: %{a: 1, b: 2}})
    |> refute_match(%{list: "hello"})
    |> refute_match(%{})

    """
    list:
      $size:
        $gt: 1
        $lte: 3
    """
    |> refute_match(%{list: []})
    |> refute_match(%{list: [1]})
    |> assert_match(%{list: [1, 2]})
    |> assert_match(%{list: [1, 2, 3]})
    |> refute_match(%{list: [1, 2, 3, 4]})
    |> refute_match(%{})

    assert_raise(RuntimeError, fn ->
      # Invalid number in $gt
      """
      list:
        $size:
          $gt: hello
      """
      |> refute_match(%{list: []})
    end)
  end

  test "nested $or > $and" do
    """
    $or:
        skippy: true
        $and:
            - kind: "a"
            - val: 10
    """
    |> assert_match(%{kind: "a", val: 10, skippy: false})
    |> assert_match(%{kind: "a", val: 10, skippy: true})
    |> assert_match(%{skippy: true})
    |> assert_match(%{kind: :other, val: 10, skippy: true})
    |> assert_match(%{kind: "a", val: 9999, skippy: true})
    |> refute_match(%{kind: "a", val: 9999, skippy: false})
  end

  test "nested $and > $or" do
    """
    $and:
        is_valid: true
        $or:
          kind: "a"
          val: 10
    """
    |> refute_match(%{kind: "a", val: 10, is_valid: false})
    |> assert_match(%{kind: "a", val: 10, is_valid: true})
    |> assert_match(%{kind: :other, val: 10, is_valid: true})
    |> assert_match(%{kind: "a", val: 9999, is_valid: true})
    |> refute_match(%{is_valid: true})
  end

  test "invert with $not" do
    """
    $not:
      a: 1
    """
    |> assert_match(%{a: 9999})
    |> refute_match(%{a: 1})

    """
    $not:
        $and:
            - kind: "a"
            - val: 10
    """
    |> refute_match(%{kind: "a", val: 10})
    |> assert_match(%{kind: :other, val: 10})
    |> assert_match(%{kind: "a", val: 9999})
  end

  test "dates with $date_lt" do
    now = DateTime.utc_now()
    later_5min = DateTime.add(now, 5 * 60, :second)
    sooner_3min = DateTime.add(now, -3 * 60, :second)
    sooner_5min = DateTime.add(now, -5 * 60, :second)

    """
    at:
      $date_lt: #{now}
    """
    |> assert_match(%{at: sooner_5min})
    |> refute_match(%{at: now})
    |> refute_match(%{at: later_5min})

    # Query matches dates that are older than 4 minutes (from now)
    """
    at:
      $date_lt: "-4m"
    """
    # 5m ago is older than 4 min ago
    |> assert_match(%{at: sooner_5min})
    # 3m ago and after that is not older
    |> refute_match(%{at: sooner_3min})
    |> refute_match(%{at: now})
    |> refute_match(%{at: later_5min})
  end

  test "compilation error" do
    assert_raise Tonka.Core.Query.MQL.Compiler.CompilationError, fn ->
      """
      at:
        $date_lt: "not-a-date"
      """
      |> all_atoms_query()
    end
  end

  test "compute a $subset and run a match" do
    """
    items:
      $subset:
        filter: { $gt: 10 }
        match: { $size: 1 }
    """
    |> assert_match(%{items: [8, 9, 10, 11]})
    |> refute_match(%{items: [10]})
    |> assert_match(%{items: [11]})
    |> refute_match(%{items: [1, 2, 3, 4, 5]})

    """
    obj:
      $subset:
        filter: { $gt: 10 }
        match:
          $elem_match: { $lt: 20 }
    """
    |> assert_match(%{obj: %{a: 8, b: 9, c: 10, d: 11}})
    |> refute_match(%{obj: %{a: 8, b: 9, c: 10, d: 20}})
    |> refute_match(%{obj: %{a: 8, b: 9, c: 10, d: 21}})
    |> refute_match(%{obj: %{a: 0}})
    |> assert_match(%{obj: %{a: 15}})

    """
    labels:
      $subset:
        filter: { $in: [todo, doing, to_estimate] }
        match: { $size: { $gt: 1 }}
    """
    |> refute_match(%{labels: ["todo"]})
    |> refute_match(%{labels: ["doing"]})
    |> assert_match(%{labels: ["todo", "doing"]})

    """
    items:
      $subset:
        filter: { $gt: 10 }
        match:
          $subset:
            filter: { $lt: 20 }
            match: { $size: 1 }
    """
    |> assert_match(%{items: [10, 19]})
    |> assert_match(%{items: [11, 20]})
    |> assert_match(%{items: [10, 15, 20]})
    |> refute_match(%{items: [8, 21]})
    |> refute_match(%{items: [10, 20]})
    |> refute_match(%{items: [10, 15, 16, 20]})
    |> refute_match(%{items: []})
  end

  test "some atoms can be opt-in" do
    query =
      """
      a: 1
      b: 2
      """
      |> decode_yaml!()

    q = Tonka.Core.Query.MQL.compile!(query, as_atoms: ["a"])

    refute MQL.match?(q, %{"a" => 1, "b" => 2})
    refute MQL.match?(q, %{a: 1, b: 2})

    # It will only match when key `a` is an atom and `b` is a binary
    assert MQL.match?(q, %{:a => 1, "b" => 2})
    assert MQL.match?(q, %{:a => 1, "b" => 2, :c => 3})
    assert MQL.match?(q, %{:a => 1, "b" => 2, "c" => 3})

    refute MQL.match?(q, %{:a => 99, "b" => 99})
    refute MQL.match?(q, %{:a => 1, "b" => 99})
    refute MQL.match?(q, %{:a => 99, "b" => 2})
  end

  defp assert_match(yaml, map) do
    {:compiled, yaml, q} = all_atoms_query(yaml)

    if MQL.match?(q, map) do
      assert true
    else
      flunk("""
      Query failed:
      #{indent(yaml, 2)}

      Decoded as:
      #{indent(inspect(q, pretty: true, charlists: :as_lists), 2)}

      Was expected to match:
      #{indent(inspect(map, pretty: true, charlists: :as_lists), 2)}
      """)
    end

    # Return the yaml to chain assertions but still print the result
    {:compiled, yaml, q}
  end

  defp refute_match(yaml, map) do
    {:compiled, yaml, q} = all_atoms_query(yaml)

    if MQL.match?(q, map) do
      flunk("""
      Query failed:
      #{indent(yaml, 2)}

      Decoded as:
      #{indent(inspect(q, pretty: true, charlists: :as_lists), 2)}

      Was expected NOT to match
      #{indent(inspect(map, pretty: true, charlists: :as_lists), 2)}
      """)
    else
      assert true
    end

    # Return the yaml to chain assertions but still print the result
    {:compiled, yaml, q}
  end

  defp all_atoms_query(yaml) when is_binary(yaml) do
    bin_keys = decode_yaml!(yaml)
    q = Tonka.Core.Query.MQL.compile!(bin_keys, as_atoms: :all)

    {:compiled, yaml, q}
  end

  defp all_atoms_query({:compiled, yaml, q}), do: {:compiled, yaml, q}

  defp indent(str, n) do
    ws = String.duplicate("  ", n)
    ws <> (str |> String.trim() |> String.replace("\n", "\n#{ws}"))
  end

  defp decode_yaml!(yaml) do
    YamlElixir.read_from_string!(yaml)
  end
end

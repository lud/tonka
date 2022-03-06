defmodule Tonka.ReflectionTest do
  alias Tonka.Core.Reflection
  use ExUnit.Case, async: true

  defmodule A do
    @callback noop() :: :ok
  end

  defmodule ImplementsA do
    @behaviour A
    def noop, do: :ok
  end

  defmodule Other do
  end

  test "behaviour is detected" do
    assert Reflection.implements_behaviour?(ImplementsA, A)
    refute Reflection.implements_behaviour?(Other, A)
  end

  test "function specs are extracted – arity 1" do
    module = Tonka.Test.Fixtures.BunchOfFunctions
    spec = Reflection.function_spec(module, :validate_integer, 1)
    assert {args, return} = spec
    assert {:term} = args

    assert {:union,
            [
              {:tuple, [{:atom, :ok}, :integer]},
              {:tuple, [atom: :error, atom: :not_an_int]}
            ]} = return
  end

  test "function specs are extracted – arity 2" do
    module = Tonka.Test.Fixtures.BunchOfFunctions
    spec = Reflection.function_spec(module, :two_args, 2)
    assert {args, return} = spec

    assert {
             {:union, [:binary, {:list, :char}, {:list, :char}]},
             :integer
           } = args

    assert :atom = return
  end

  test "extract fun argument" do
    module = Tonka.Test.Fixtures.BunchOfFunctions
    spec = Reflection.function_spec(module, :accepts_fun_and_arg, 2)
    assert {args, return} = spec

    assert {{{:integer}, :binary}, :integer} = args

    assert :binary = return
  end

  test "extract module type" do
    type = Reflection.type(Tonka.Test.Fixtures.OpOneInput, :output)
    assert :binary = type
  end

  test "extract module type when it is a map with know keys" do
    module = Tonka.Test.Fixtures.BunchOfFunctions
    spec = Reflection.type(module, :some_map)
    assert {:map, a_key: :binary, other_key: :integer} = spec
  end
end

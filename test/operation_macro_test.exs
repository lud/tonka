defmodule Tonka.OperationMacroTest do
  alias Tonka.Core.Operation
  alias Tonka.Core.Reflection
  alias Tonka.Test.Fixtures.OpNoInputs
  alias Tonka.Test.Fixtures.OpOneInexistingInput
  use ExUnit.Case, async: true

  test "the __using__ macro defines operation behaviour" do
    assert Reflection.implements_behaviour?(OpNoInputs, Operation)
  end

  test "the __using__ macro exports input_specs/0 when no input is declared" do
    assert Reflection.load_function_exported?(OpNoInputs, :input_specs, 0)

    {args, return} = Reflection.function_spec(OpNoInputs, :input_specs, 0)
    assert 0 = tuple_size(args)
    assert {:list, {:remote_type, Tonka.Core.Operation.InputSpec, :t}} = return

    assert [] = OpNoInputs.input_specs()
  end

  test "the __using__ macro exports the actual input specs with typespec" do
    assert Reflection.load_function_exported?(OpOneInexistingInput, :input_specs, 0)

    {args, return} = Reflection.function_spec(OpOneInexistingInput, :input_specs, 0)
    assert 0 = tuple_size(args)
    assert {:list, {:remote_type, Tonka.Core.Operation.InputSpec, :t}} = return

    assert [%Operation.InputSpec{}] = OpOneInexistingInput.input_specs()
  end
end

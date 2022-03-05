defmodule Tonka.OperationMacroTest do
  alias Tonka.Core.Operation
  alias Tonka.Core.Reflection
  alias Tonka.Test.Fixtures.OpNoInputs
  use ExUnit.Case, async: true

  test "the __using__ macro defines operation behaviour" do
    assert Reflection.implements_behaviour?(OpNoInputs, Operation)
  end

  test "the input macro exports the required input spec" do
    assert function_exported?(OpNoInputs, :input_specs, 0)
    OpNoInputs.input_specs()

    {args, return} = Reflection.function_spec(OpNoInputs, :input_specs, 0)
    assert 0 = tuple_size(args)
    assert {:list, {:remote_type, Tonka.Core.Operation.InputSpec, :t}} = return
  end
end

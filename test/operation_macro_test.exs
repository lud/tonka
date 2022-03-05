defmodule Tonka.OperationMacroTest do
  alias Tonka.Core.Operation
  alias Tonka.Core.Reflection
  alias Tonka.Test.Fixtures.OpNoInputs
  alias Tonka.Test.Fixtures.OpOneInexistingInput
  use ExUnit.Case, async: true

  test "using defines operation behaviour" do
    assert Reflection.implements_behaviour?(OpNoInputs, Operation)
  end

  test "using exports input_specs/0 when no input is declared" do
    assert Reflection.load_function_exported?(OpNoInputs, :input_specs, 0)

    {args, return} = Reflection.function_spec(OpNoInputs, :input_specs, 0)
    assert 0 = tuple_size(args)
    assert {:list, {:remote_type, Tonka.Core.Operation.InputSpec, :t}} = return

    assert [] = OpNoInputs.input_specs()
  end

  test "using exports the actual input specs with typespec" do
    assert Reflection.load_function_exported?(OpOneInexistingInput, :input_specs, 0)

    {args, return} = Reflection.function_spec(OpOneInexistingInput, :input_specs, 0)
    assert 0 = tuple_size(args)
    assert {:list, {:remote_type, Tonka.Core.Operation.InputSpec, :t}} = return

    assert [%Operation.InputSpec{type: A.B.C, key: :myvar}] = OpOneInexistingInput.input_specs()
  end

  test "using exports the output spec with typespec" do
    assert Reflection.load_function_exported?(OpOneInexistingInput, :output_spec, 0)

    {args, return} = Reflection.function_spec(OpOneInexistingInput, :output_spec, 0)
    assert 0 = tuple_size(args)
    assert {:remote_type, Tonka.Core.Operation.OutputSpec, :t} = return

    assert %Operation.OutputSpec{type: X.Y.Z} = OpOneInexistingInput.output_spec()
  end

  # test "using the call macro defines the call callback" do
  #   assert Reflection.load_function_exported?(OpOneInexistingInput, :call, 3)

  #   {args, return} = Reflection.function_spec(OpOneInexistingInput, :output_spec, 0)
  #   assert 0 = tuple_size(args)
  #   assert {:remote_type, Tonka.Core.Operation.OutputSpec, :t} = return

  #   assert %Operation.OutputSpec{type: X.Y.Z} = OpOneInexistingInput.output_spec()
  # end
end

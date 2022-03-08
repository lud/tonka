defmodule Tonka.OperationMacroTest do
  alias Tonka.Core.Operation
  alias Tonka.Core.Reflection
  alias Tonka.Test.Fixtures.OpNoInputs
  alias Tonka.Test.Fixtures.OpOneInput
  alias Tonka.Test.Fixtures.OpOneInput.MyInput
  use ExUnit.Case, async: true

  test "using defines operation behaviour" do
    assert Reflection.implements_behaviour?(OpNoInputs, Operation)
  end

  test "using exports input_specs/0 when no input is declared" do
    assert Reflection.load_function_exported?(OpNoInputs, :input_specs, 0)

    {args, return} = Reflection.function_spec(OpNoInputs, :input_specs, 0)
    assert 0 = tuple_size(args)
    assert {:list, {:remote_type, Tonka.Core.Container.InjectSpec, :t}} = return

    assert [] = OpNoInputs.input_specs()
  end

  test "using macro exports the actual input specs with typespec" do
    assert Reflection.load_function_exported?(OpOneInput, :input_specs, 0)

    {args, return} = Reflection.function_spec(OpOneInput, :input_specs, 0)
    assert 0 = tuple_size(args)
    assert {:list, {:remote_type, Tonka.Core.Container.InjectSpec, :t}} = return

    assert [
             %Tonka.Core.Container.InjectSpec{
               type: Tonka.Test.Fixtures.OpOneInput.MyInput,
               key: :myvar
             }
           ] = OpOneInput.input_specs()
  end

  test "using macro exports the output spec with typespec" do
    assert Reflection.load_function_exported?(OpOneInput, :output_spec, 0)

    {args, return} = Reflection.function_spec(OpOneInput, :output_spec, 0)
    assert 0 = tuple_size(args)
    assert {:remote_type, Tonka.Core.Operation.OutputSpec, :t} = return

    assert %Operation.OutputSpec{type: Tonka.Test.Fixtures.OpOneInput.MyOutput} =
             OpOneInput.output_spec()
  end

  test "using the call macro defines the call callback" do
    assert Reflection.load_function_exported?(OpOneInput, :call, 3)

    {args, return} = Reflection.function_spec(OpOneInput, :call, 3)

    # check the output

    assert :binary = Reflection.type(OpOneInput, :output)

    assert {
             :remote_type,
             Tonka.Core.Operation,
             :op_out,
             [user_type: :output]
           } = return

    # check the input

    assert 3 = tuple_size(args)
    {input_types, param_type, inject_type} = args

    assert {:user_type, :input_map} = input_types
    assert :map = param_type
    assert :map = inject_type

    assert {:map, [myvar: {:remote_type, MyInput, :t}]} = Reflection.type(OpOneInput, :input_map)

    assert {:ok, "HELLO_SUF"} == OpOneInput.call(%{myvar: %MyInput{text: "hello"}}, %{}, %{})
  end
end

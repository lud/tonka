defmodule Tonka.ContainerMacroTest do
  alias Tonka.Core.Container
  alias Tonka.Core.Container.Service
  alias Tonka.Core.Container.InjectSpec
  alias Tonka.Core.Container.ReturnSpec
  alias Tonka.Core.Operation
  alias Tonka.Core.Reflection
  alias Tonka.Test.Fixtures.SampleService
  alias Tonka.Test.Fixtures.SampleServiceNoInjects
  use ExUnit.Case, async: true

  test "using defines service behaviour" do
    assert Reflection.implements_behaviour?(SampleServiceNoInjects, Service)
  end

  test "using macro exports inject_specs/0 when no inject is declared" do
    assert Reflection.load_function_exported?(SampleServiceNoInjects, :inject_specs, 3)

    {args, return} = Reflection.function_spec(SampleServiceNoInjects, :inject_specs, 3)
    assert 3 = tuple_size(args)
    assert {:list, {:remote_type, InjectSpec, :t}} = return

    assert {:atom, :non_neg_integer, :non_neg_integer} = args

    assert [] = Service.inject_specs(SampleServiceNoInjects)
  end

  test "using macros exports the actual inject specs with typespec" do
    assert Reflection.load_function_exported?(SampleService, :inject_specs, 3)

    {args, return} = Reflection.function_spec(SampleService, :inject_specs, 3)
    assert 3 = tuple_size(args)
    assert {:list, {:remote_type, InjectSpec, :t}} = return

    assert {:atom, :non_neg_integer, :non_neg_integer} = args

    assert [
             %InjectSpec{
               type: Tonka.Test.Fixtures.SampleService.Dependency,
               key: :dep
             }
           ] = Service.inject_specs(SampleService)
  end

  test "using macro exports the provides spec with typespec" do
    assert Reflection.load_function_exported?(SampleService, :provides_spec, 0)

    {args, return} = Reflection.function_spec(SampleService, :provides_spec, 0)
    assert 0 = tuple_size(args)
    assert {:remote_type, ReturnSpec, :t} = return

    assert %ReturnSpec{type: Tonka.Test.Fixtures.SampleService} = SampleService.provides_spec()
  end

  test "using the init macro defines the call callback" do
    assert Reflection.load_function_exported?(SampleService, :init, 1)

    #   {args, return} = Reflection.function_spec(SampleService, :call, 3)

    #   # check the output

    #   assert :binary = Reflection.type(SampleService, :output)

    #   assert {
    #            :remote_type,
    #            Tonka.Core.Operation,
    #            :op_out,
    #            [user_type: :output]
    #          } = return

    #   # check the inject

    #   assert 3 = tuple_size(args)
    #   {inject_types, param_type, inject_type} = args

    #   assert {:user_type, :inject_map} = inject_types
    #   assert :map = param_type
    #   assert :map = inject_type

    #   assert {:map, [myvar: {:remote_type, Myinject, :t}]} = Reflection.type(SampleService, :inject_map)

    #   assert {:ok, "HELLO_SUF"} == SampleService.call(%{myvar: %Myinject{text: "hello"}}, %{}, %{})
  end
end

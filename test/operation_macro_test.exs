defmodule Tonka.OperationMacroTest do
  alias Tonka.Core.Operation
  alias Tonka.Core.Reflection
  use ExUnit.Case, async: true

  defmodule SampleOp do
    use Operation
  end

  test "the __using__ macro defines operation behaviour" do
    assert Reflection.implements_behaviour?(SampleOp, Operation)
  end

  test "the input macro exports the required input spec" do
    assert Reflection.implements_behaviour?(SampleOp, Operation)
  end
end

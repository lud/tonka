defmodule Tonka.OperationMacroTest do
  alias Tonka.Core.Grid
  alias Tonka.Core.Operation
  alias Tonka.Core.Grid.InvalidInputTypeError
  use ExUnit.Case, async: true

  defmodule SampleOp do
    use Operation
  end

  test "the macro defines operation behaviour" do
  end
end

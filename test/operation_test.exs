defmodule Tonka.OperationTest do
  alias Tonka.Core.Grid
  alias Tonka.Core.Operation
  alias Tonka.Core.Container
  alias Tonka.Core.Grid.InvalidInputTypeError
  use ExUnit.Case, async: true

  defmodule ASimpleOp do
    use Operation

    def cast_params(raw) do
      send(self(), {__MODULE__, :params_casted})
      {:ok, raw}
    end
  end

  test "it is possible to define an operation" do
    assert %Operation{} = Operation.new(ASimpleOp)
  end

  test "it is possible precast the params of an operation" do
    # the params will be casted only once. This is because on grid
    # initialization we want to cast the params of all operations, then get the
    # config of all operations to validate the grid wiring (inputs and injects),
    # then only run each operation one by one.
    op = Operation.new(ASimpleOp)
    assert {:ok, op} = Operation.precast_params(op)
    assert_receive {ASimpleOp, :params_casted}

    # on the second call we will not receive the message from the cast_params
    # callback
    assert {:ok, op} = Operation.precast_params(op)
    refute_receive {ASimpleOp, :params_casted}
  end
end

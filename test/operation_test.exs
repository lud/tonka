defmodule Tonka.OperationTest do
  alias Tonka.Core.Grid
  alias Tonka.Core.Operation
  alias Tonka.Core.Container
  alias Tonka.Core.Grid.InvalidInputTypeError
  use ExUnit.Case, async: true

  defmodule ASimpleOp do
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
    assert {:ok, _op} = Operation.precast_params(op)
    refute_receive {ASimpleOp, :params_casted}
  end

  defmodule RejectsParams do
    def cast_params(raw) do
      send(self(), {__MODULE__, :params_casted})
      {:error, :rejected}
    end
  end

  test "an operation can reject its params" do
    op = Operation.new(RejectsParams)
    assert {:error, :rejected} = Operation.precast_params(op)
    IO.warn("todo test that we get that error with configure/call if the params are not cached")
  end

  defmodule ConfigurableOp do
    def cast_params(raw) do
      send(self(), {__MODULE__, :params_casted})
      {:ok, :my_params}
    end

    def configure(config, :my_params) do
      send(self(), {__MODULE__, :configured})
      config
    end
  end

  test "it is possible to get an operation config" do
    op = Operation.new(ConfigurableOp)

    assert {:ok, op} = Operation.preconfigure(op)
    assert_receive {ConfigurableOp, :params_casted}
    assert_receive {ConfigurableOp, :configured}

    # on the second call we will not receive the message from the cast_params
    # callback
    assert {:ok, _op} = Operation.preconfigure(op)
    refute_receive {ConfigurableOp, :params_casted}
    refute_receive {ConfigurableOp, :configured}
  end

  test "adding inputs to op config" do
    Operation.base_config()
    |> Operation.use_input(:mykey, SomeInput)

    # raise "todo test use_service"
    # raise "todo test get_inputs"
    # raise "todo test get_injects"
  end
end

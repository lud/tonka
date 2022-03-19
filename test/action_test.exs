defmodule Tonka.ActionTest do
  alias Tonka.Core.Grid
  alias Tonka.Core.Action
  alias Tonka.Core.Container
  alias Tonka.Core.Grid.InvalidInputTypeError
  use ExUnit.Case, async: true

  defmodule ASimpleOp do
    def cast_params(raw) do
      send(self(), {__MODULE__, :params_casted})
      {:ok, raw}
    end
  end

  test "it is possible to define an action" do
    assert %Action{} = Action.new(ASimpleOp)
  end

  test "it is possible precast the params of an action" do
    # the params will be casted only once. This is because on grid
    # initialization we want to cast the params of all actions, then get the
    # config of all actions to validate the grid wiring (inputs and injects),
    # then only run each action one by one.
    act = Action.new(ASimpleOp)
    assert {:ok, act} = Action.precast_params(act)
    assert_receive {ASimpleOp, :params_casted}

    # on the second call we will not receive the message from the cast_params
    # callback
    assert {:ok, _op} = Action.precast_params(act)
    refute_receive {ASimpleOp, :params_casted}
  end

  defmodule RejectsParams do
    def cast_params(raw) do
      send(self(), {__MODULE__, :params_casted})
      {:error, :rejected}
    end
  end

  test "an action can reject its params" do
    act = Action.new(RejectsParams)
    assert {:error, :rejected} = Action.precast_params(act)
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

  test "it is possible to get an action config" do
    act = Action.new(ConfigurableOp)

    assert {:ok, act} = Action.preconfigure(act)
    assert_receive {ConfigurableOp, :params_casted}
    assert_receive {ConfigurableOp, :configured}

    # on the second call we will not receive the message from the cast_params
    # callback
    assert {:ok, _op} = Action.preconfigure(act)
    refute_receive {ConfigurableOp, :params_casted}
    refute_receive {ConfigurableOp, :configured}
  end

  test "adding inputs to act config" do
    Action.base_config()
    |> Action.use_input(:mykey, SomeInput)

    # raise "todo test use_service"
    # raise "todo test get_inputs"
    # raise "todo test get_injects"
  end
end

defmodule Tonka.GridTest do
  alias Tonka.Core.Grid
  alias Tonka.Core.Action
  alias Tonka.Core.Container
  alias Tonka.Core.Grid.InvalidInputTypeError
  use ExUnit.Case, async: true

  defmodule NoCaster do
    @behaviour Tonka.Core.InputCaster

    def for_type(type) do
      Tonka.Core.InputCaster.new(module: __MODULE__, output_spec: _output_spec(type))
    end

    def _output_spec(type) do
      %Container.ReturnSpec{type: type}
    end

    def output_spec() do
      raise "#{inspect(__MODULE__)}.output_spec/0 cannot be called directly"
    end

    def call(term, _, _) do
      term
    end
  end

  test "a grid can be created" do
    grid = Grid.new()
    assert is_struct(grid, Grid)
  end

  defmodule Noop do
  end

  test "it is possible to add an action to a grid" do
    grid = Grid.new()
    grid = Grid.add_action(grid, "a", Noop)
    assert is_struct(grid, Grid)
  end

  test "it is possible to add two actions with the same module" do
    grid =
      Grid.new()
      |> Grid.add_action("a", Noop)
      |> Grid.add_action("b", Noop)

    assert is_struct(grid, Grid)
  end

  test "it is not possible to add two actions with the same key" do
    assert_raise ArgumentError, ~r/"a" is already defined/, fn ->
      Grid.new()
      |> Grid.add_action("a", Noop)
      |> Grid.add_action("a", Noop)
    end
  end

  defmodule MessageParamSender do
    def cast_params(it), do: {:ok, it}

    def configure(config, _) do
      config
      |> Action.use_input(:parent, {:raw, :pid})
    end

    def output_spec() do
      %Container.ReturnSpec{
        type: {:raw, :atom}
      }
    end

    def call(%{parent: parent}, %{message: message}, _) do
      send(parent, message)
      :ok
    end
  end

  test "it is possible to run the grid" do
    # As an action has the grid input mapped to one of its inputs, the grid
    # must cast that input to the expected type.

    this = self()
    ref = make_ref()

    grid =
      Grid.new()
      |> Grid.add_action("a", MessageParamSender,
        params: %{message: {ref, "hello"}},
        inputs: %{parent: Grid.static_input(self())}
      )

    assert {:ok, _} = Grid.run(grid, this)
    assert_receive {^ref, "hello"}
  end

  defmodule Upcaser do
    def cast_params(it), do: {:ok, it}

    def input_specs() do
      [
        %Container.InjectSpec{
          key: :text,
          type: {:raw, :binary}
        }
      ]
    end

    def output_spec() do
      %Container.ReturnSpec{
        type: {:raw, :term}
      }
    end

    def call(%{text: text}, %{tag: tag}, _) do
      {tag, String.upcase(text)}
    end
  end

  defmodule InputMessageSender do
    def cast_params(it), do: {:ok, it}

    def input_specs() do
      [
        %Container.InjectSpec{
          key: :message,
          type: {:raw, :term}
        }
      ]
    end

    def output_spec() do
      %Container.ReturnSpec{
        type: {:raw, :atom}
      }
    end

    def call(%{message: message}, %{parent: parent}, _) do
      send(parent, message)
      :ok
    end
  end

  @tag :skip
  test "an action can use another action output as input" do
    this = self()
    ref = make_ref()

    grid =
      Grid.new()
      |> Grid.set_input(NoCaster.for_type({:raw, :binary}))
      |> Grid.add_action("a", InputMessageSender,
        inputs: %{message: "b"},
        params: %{parent: this}
      )
      |> Grid.add_action("b", Upcaser,
        inputs: %{text: :incast},
        params: %{tag: ref}
      )

    assert {:ok, _} = Grid.run(grid, "hello")

    assert_receive {^ref, "HELLO"}
  end

  defmodule RequiresAText do
    @behaviour Action

    def cast_params(it), do: {:ok, it}

    def input_specs() do
      [
        %Container.InjectSpec{
          key: :mytext,
          type: {:raw, :binary}
        }
      ]
    end

    def output_spec() do
      %Container.ReturnSpec{
        type: {:raw, :atom}
      }
    end

    def call(%{mytext: mytext}, %{parent: parent, tag: tag}, _)
        when is_binary(mytext) do
      message = {tag, String.upcase(mytext)}
      send(parent, message)
      :ok
    end
  end

  defmodule ProvidesAText do
    @behaviour Action

    def cast_params(it), do: {:ok, it}

    def input_specs() do
      []
    end

    def output_spec() do
      %Container.ReturnSpec{
        type: {:raw, :binary}
      }
    end

    def call(_, _, _) do
      Base.encode16(:crypto.strong_rand_bytes(12))
    end
  end

  defmodule ProvidesAnInt do
    @behaviour Action

    def cast_params(it), do: {:ok, it}

    def input_specs() do
      []
    end

    def output_spec() do
      %Container.ReturnSpec{
        type: {:raw, :integer}
      }
    end

    def call(_, _, _) do
      :erlang.system_time()
    end
  end

  @tag :skip
  test "the grid will verify that the actions are compatible - ok" do
    ref = make_ref()

    grid =
      Grid.new()
      |> Grid.set_input(NoCaster.for_type({:raw, :pid}))
      |> Grid.add_action("consumer", RequiresAText,
        inputs: %{mytext: "provider"},
        params: %{parent: self(), tag: ref}
      )
      |> Grid.add_action("provider", ProvidesAText, inputs: %{_: :incast})

    assert {:ok, _} = Grid.run(grid, "hello")

    assert_receive {^ref, text} when is_binary(text)
  end

  @tag :skip
  test "the grid will verify that the actions are compatible - error" do
    ref = make_ref()

    grid =
      Grid.new()
      |> Grid.set_input(NoCaster.for_type({:raw, :pid}))
      |> Grid.add_action("consumer", RequiresAText,
        inputs: %{mytext: "provider"},
        params: %{parent: self(), tag: ref}
      )
      # Here we provide and integer to the consumer, which cannt work
      |> Grid.add_action("provider", ProvidesAnInt, inputs: %{_: :incast})

    # At this point everything is fine. But when we will try to build the grid
    # it will fail. It must not fail because of the guard in:
    #
    #     def call(%{mytext: mytext}, %{parent: parent, tag: tag}, _)
    #         when is_binary(mytext)
    #
    # But rather raise an exception regarding the control of inputs

    input = "some raw string"

    assert match?(
             {:error, {:invalid_inputs, [%InvalidInputTypeError{}]}},
             Grid.validate(grid)
           )

    assert_raise InvalidInputTypeError, fn ->
      assert {:ok, _} = Grid.run(grid, input)
    end
  end

  @tag :skip
  test "the grid will verify that the grid input is mapped" do
    grid =
      Grid.new()
      |> Grid.add_action("consumer", RequiresAText, inputs: %{mytext: "provider"})
      # Here we provide and integer to the consumer, which cannt work
      |> Grid.add_action("provider", ProvidesAnInt, inputs: %{_: :incast})

    assert_raise Grid.NoInputCasterError, fn ->
      assert {:ok, _} = Grid.run(grid, :some_input)
    end
  end

  @tag :skip
  test "the grid will verify that every input is mapped" do
    grid =
      Grid.new()
      |> Grid.set_input(NoCaster.for_type({:raw, :pid}))
      # here we do not map the input :mytext for RequiresAText
      |> Grid.add_action("consumer", RequiresAText)

    assert_raise Grid.UnmappedInputError, fn ->
      assert {:ok, _} = Grid.run(grid, :some_input)
    end
  end
end

defmodule Tonka.GridTest do
  alias Tonka.Core.Grid
  alias Tonka.Core.Action
  alias Tonka.Core.Container
  alias Tonka.Core.Grid.InvalidInputTypeError
  use ExUnit.Case, async: true

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

    def call(%{parent: parent}, _, %{message: message}) do
      send(parent, message)
      {:ok, nil}
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
        inputs: %{} |> Grid.pipe_static(:parent, self())
      )

    assert {:ok, :done, _} = Grid.run(grid, this)
    assert_receive {^ref, "hello"}
  end

  defmodule Upcaser do
    def cast_params(it), do: {:ok, it}

    def return_type, do: {:raw, :binary}

    def configure(config, _) do
      config
      |> Action.use_input(:text, {:raw, :binary})
    end

    def call(%{text: text}, _, %{tag: tag}) do
      {:ok, {tag, String.upcase(text)}}
    end
  end

  defmodule InputMessageSender do
    def cast_params(it), do: {:ok, it}

    def configure(config, _) do
      config
      |> Action.use_input(:message, {:raw, :binary})
    end

    def call(%{message: message}, _, %{parent: parent}) do
      send(parent, message)
      {:ok, nil}
    end
  end

  test "an action can use another action output as input" do
    this = self()
    ref = make_ref()

    grid =
      Grid.new()
      |> Grid.add_action("a", InputMessageSender,
        inputs: %{} |> Grid.pipe_action(:message, "b"),
        params: %{parent: this}
      )
      |> Grid.add_action("b", Upcaser,
        inputs: %{} |> Grid.pipe_grid_input(:text),
        params: %{tag: ref}
      )

    assert {:ok, :done, _} = Grid.run(grid, "hello")

    assert_receive {^ref, "HELLO"}
  end

  defmodule RequiresAText do
    @behaviour Action

    def cast_params(it), do: {:ok, it}

    def call(%{mytext: mytext}, _, %{parent: parent, tag: tag})
        when is_binary(mytext) do
      message = {tag, String.upcase(mytext)}
      send(parent, message)
      :ok
    end
  end

  defmodule ProvidesAText do
    @behaviour Action

    def cast_params(it), do: {:ok, it}

    def call(_, _, _) do
      Base.encode16(:crypto.strong_rand_bytes(12))
    end
  end

  defmodule ProvidesAnInt do
    @behaviour Action

    def cast_params(it), do: {:ok, it}

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

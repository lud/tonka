defmodule Tonka.GridTest do
  alias Tonka.Core.Grid
  use ExUnit.Case, async: true

  test "a grid can be created" do
    grid = Grid.new()
    assert is_struct(grid, Grid)
  end

  defmodule Noop do
  end

  test "it is possible to add an operation to a grid" do
    grid = Grid.new()
    grid = Grid.add_operation(grid, "a", Noop)
    assert is_struct(grid, Grid)
  end

  test "it is possible to add two operations with the same module" do
    grid =
      Grid.new()
      |> Grid.add_operation("a", Noop)
      |> Grid.add_operation("b", Noop)

    assert is_struct(grid, Grid)
  end

  test "it is not possible to add two operations with the same key" do
    assert_raise ArgumentError, ~r/"a" is already defined/, fn ->
      Grid.new()
      |> Grid.add_operation("a", Noop)
      |> Grid.add_operation("a", Noop)
    end
  end

  defmodule MessageParamSender do
    def call(%{parent: parent}, %{Tonka.T.Params => %{message: message}}) do
      send(parent, message)
    end
  end

  test "it is possible to run the grid" do
    this = self()
    ref = make_ref()

    grid =
      Grid.new()
      |> Grid.add_operation("a", MessageParamSender,
        from: %{parent: :input},
        params: %{message: {ref, "hello"}}
      )

    Grid.run(grid, this)
    assert_receive {^ref, "hello"}
  end

  defmodule Upcaser do
    def call(%{text: text}, %{Tonka.T.Params => %{tag: tag}}) do
      {tag, String.upcase(text)}
    end
  end

  defmodule InputMessageSender do
    def call(%{message: message}, %{Tonka.T.Params => %{parent: parent}}) do
      send(parent, message)
      :ok
    end
  end

  test "an operation can use another operation output as input" do
    this = self()
    ref = make_ref()

    grid =
      Grid.new()
      |> Grid.add_operation("a", InputMessageSender,
        from: %{message: "b"},
        params: %{parent: this}
      )
      |> Grid.add_operation("b", Upcaser,
        from: %{text: :input},
        params: %{tag: ref}
      )

    Grid.run(grid, "hello")
    |> IO.inspect(label: "grid ran")

    assert_receive {^ref, "HELLO"}
  end
end

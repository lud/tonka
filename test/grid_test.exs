defmodule Tonka.GridTest do
  alias Tonka.Core.Grid
  use ExUnit.Case, async: true

  test "a grid can be created" do
    grid = Grid.new()
    assert is_struct(grid, Grid)
  end

  defmodule Op1 do
  end

  test "it is possible to add an operation to a grid" do
    grid = Grid.new()
    grid = Grid.add_operation(grid, "op1", Op1)
    assert is_struct(grid, Grid)
  end

  test "it is possible to add two operations with the same module" do
    grid =
      Grid.new()
      |> Grid.add_operation("a", Op1)
      |> Grid.add_operation("b", Op1)

    assert is_struct(grid, Grid)
  end

  test "it is not possible to add two operations with the same key" do
    assert_raise ArgumentError, ~r/"a" is already defined/, fn ->
      Grid.new()
      |> Grid.add_operation("a", Op1)
      |> Grid.add_operation("a", Op1)
    end
  end

  test "it is possible to run the grid" do
    grid = Grid.new() |> Grid.add_operation("a", Op1)
    Grid.run(grid)
  end
end

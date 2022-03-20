defmodule Tonka.GridInjectionTest do
  alias Tonka.Core.Grid
  alias Tonka.Core.Action
  alias Tonka.Core.Container
  alias Tonka.Core.Grid.InvalidInputTypeError
  alias Tonka.Core.Grid.NoInputCasterError
  alias Tonka.Core.Grid.UnmappedInputError

  use ExUnit.Case, async: true

  test "the grid expects a frozen container to run" do
    grid = Grid.new()
    container = Container.new()

    assert_raise ArgumentError, ~r/to be frozen/, fn ->
      Grid.run(grid, container, "some input")
    end
  end
end

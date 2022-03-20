defmodule Tonka.GridInjectionTest do
  alias Tonka.Core.Grid
  alias Tonka.Core.Action
  alias Tonka.Core.Container
  alias Tonka.Core.Container.Service
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

  test "the grid accepts a frozen container" do
    grid = Grid.new()
    container = Container.new() |> Container.freeze()

    assert {:ok, :done, _} = Grid.run(grid, container, "some input")
  end

  defmodule StringProvider do
    def new(string) do
      %{string: string}
    end

    def get_string!(%{string: string}), do: string
  end

  defmodule UsesService do
    use Action

    def cast_params(term), do: {:ok, term}

    def configure(config, params) do
      config
      |> Action.use_service(:myserv, StringProvider)
    end

    def call(action_in, injects, params) do
      string = StringProvider.get_string!(injects.myserv)
      send(self(), {:got_string, string})
      {:ok, nil}
    end
  end

  test "the grid will pull services from the container when calling actions" do
    grid =
      Grid.new()
      |> Grid.add_action("my_action", UsesService)

    container =
      Container.new()
      |> Container.freeze()

    assert {:ok, :done, _} = Grid.run(grid, container, "some_input")
  end
end

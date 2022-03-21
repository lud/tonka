defmodule Tonka.GridInjectionTest do
  alias Tonka.Core.Grid
  alias Tonka.Core.Action
  alias Tonka.Core.Container
  alias Tonka.Core.Container.ServiceResolutionError
  alias Tonka.Core.Service
  alias Tonka.Core.Grid.InvalidInputTypeError
  alias Tonka.Core.Grid.UnavailableServiceError
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

  defmodule UsesNonExistingService do
    use Action

    def cast_params(term), do: {:ok, term}

    def configure(config) do
      config
      |> Action.use_service(:myserv, MissingService)
    end

    def call(inputs, injects, params) do
      raise "should not be called"
    end
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

    def configure(config) do
      config
      |> Action.use_service(:myserv, StringProvider)
    end

    def call(inputs, injects, params) do
      string = StringProvider.get_string!(injects.myserv)
      send(self(), {:got_string, string})
      {:ok, nil}
    end
  end

  test "the grid will check that the container defines the used service" do
    grid =
      Grid.new()
      |> Grid.add_action("my_action", UsesService)

    container =
      Container.new()
      |> Container.freeze()

    assert {
             :error,
             {:invalid_injects,
              [
                %UnavailableServiceError{
                  action_key: "my_action",
                  container_error: %ServiceResolutionError{
                    errkind: :not_found,
                    utype: StringProvider
                  },
                  inject_key: :myserv
                }
              ]},
             _
           } = Grid.run(grid, container, "some_input")
  end

  test "the grid will fail pulling a service that is not built" do
    grid =
      Grid.new()
      |> Grid.add_action("my_action", UsesService)

    container =
      Container.new()
      |> Container.bind(StringProvider)
      |> Container.freeze()

    assert {:error,
            {:invalid_injects,
             [
               %UnavailableServiceError{
                 action_key: "my_action",
                 container_error: %ServiceResolutionError{
                   errkind: :build_frozen,
                   utype: StringProvider
                 },
                 inject_key: :myserv
               }
             ]}, _} = Grid.run(grid, container, "some_input")
  end

  test "the grid will pull services from the container when calling actions" do
    grid =
      Grid.new()
      |> Grid.add_action("my_action", UsesService)

    string = Base.encode64(:crypto.strong_rand_bytes(10))

    container =
      Container.new()
      |> Container.bind_impl(StringProvider, StringProvider.new(string))
      |> Container.prebuild_all()
      |> Ark.Ok.uok!()
      |> Container.freeze()

    assert {:ok, :done, _} = Grid.run(grid, container, "some_input")

    assert_receive {:got_string, ^string}
  end
end

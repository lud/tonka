defmodule Tonka.ContainerTest do
  alias Tonka.Core.Container
  alias Tonka.Core.Injector
  use ExUnit.Case, async: true

  test "a new container can be created" do
    container = Container.new()
    assert %Container{} = container
  end

  defmodule SomeStructService do
    @behaviour Container.Service

    defstruct []

    def inject_specs(:init, 1, 0), do: []

    def init(_) do
      send(self(), {:building, __MODULE__})
      {:ok, %__MODULE__{}}
    end
  end

  defmodule SomeDependentStruct do
    @behaviour Container.Service

    defstruct []

    def inject_specs(:init, 1, 0),
      do: [%Container.InjectSpec{key: :mykey, type: SomeStructService}]

    def init(%{mykey: %Tonka.ContainerTest.SomeStructService{} = dependency}) do
      {:ok, %__MODULE__{}}
    end
  end

  test "a struct service module can be registered and pulled" do
    # When a single atom is registered, it is considered as a utype (a userland
    # abstract type).
    assert %Container{} = container = Container.bind(Container.new(), SomeStructService)

    refute_receive {:building, SomeStructService}

    assert {:ok, %SomeStructService{}, %Container{}} =
             Container.pull(container, SomeStructService)

    assert_receive {:building, SomeStructService}
  end

  test "using a single argument to bind/1" do
    require Logger

    Logger.warn("""
    # Given we do not provide an implementation, the container should expect
    # that the utype name is also a module that produces this utype.
    """)
  end

  test "a struct service can depdend on another" do
    # When a single atom is registered, it is considered as a utype (a userland
    # abstract type). Given we do not provide an implementation, the container
    # expects that it is not only a Tonka.Core.Container.Type but also a
    container =
      Container.new()
      |> Container.bind(SomeStructService)
      |> Container.bind(SomeDependentStruct)

    refute_receive {:building, SomeStructService}

    assert {:ok, %SomeDependentStruct{}, %Container{}} =
             Container.pull(container, SomeDependentStruct)

    assert_receive {:building, SomeStructService}
  end

  test "a service value can be immediately set" do
    container =
      Container.new()
      |> Container.bind_impl(SomeStructService, %SomeStructService{})
      |> Container.bind(SomeDependentStruct)

    assert {:ok, %SomeDependentStruct{}, %Container{}} =
             Container.pull(container, SomeDependentStruct)

    refute_receive {:building, SomeStructService}
  end

  test "the container can tell if it has a service" do
    container = Container.bind(Container.new(), SomeStructService)
    assert Container.has?(container, SomeStructService)
    refute Container.has?(container, SomeDependentStruct)

    refute_receive {:building, SomeStructService}
  end

  test "a service can be built with a builder function" do
    container =
      Container.new()
      |> Container.bind(SomeStructService)
      |> Container.bind(SomeDependentStruct, fn c ->
        # This is not a refenrece implementation of a builder function. This is
        # basically what the container and service do when using macros.  An
        # actual builder function would create the service not by calling init/1
        # but using another API.
        with {:ok, deps, c} <-
               Injector.build_injects(c, SomeDependentStruct.inject_specs(:init, 1, 0)),
             {:ok, impl} <- SomeDependentStruct.init(deps) do
          {:ok, impl, c}
        else
          {:error, _} = err -> err
        end
      end)

    assert {:ok, service, %Container{}} = Container.pull(container, SomeDependentStruct)

    assert is_struct(service, SomeDependentStruct)
  end
end

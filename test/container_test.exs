defmodule Tonka.ContainerTest do
  alias Tonka.Core.Container
  alias Tonka.Core.Reflection
  alias Tonka.Test.Fixtures.OpNoInputs
  alias Tonka.Test.Fixtures.OpOneInput
  use ExUnit.Case, async: true

  test "a new container can be created" do
    container = Container.new()
    assert %Container{} = container
  end

  defmodule SomeStructService do
    @behaviour Container.Service

    defstruct []

    def build_specs, do: []

    def init(_) do
      send(self(), {:building, __MODULE__})
      {:ok, %__MODULE__{}}
    end
  end

  defmodule SomeDependentStruct do
    @behaviour Container.Service

    defstruct []

    def build_specs, do: [%Container.InjectSpec{key: :mykey, type: SomeStructService}]

    def init(%{mykey: %Tonka.ContainerTest.SomeStructService{} = dependency}) do
      dependency |> IO.inspect(label: "dependency")
      {:ok, %__MODULE__{}}
    end
  end

  test "a struct service module can be registered and pulled" do
    # When a single atom is registered, it is considered as a utype (a userland
    # abstract type). Given we do not provide an implementation, the container
    # expects that it is not only a Tonka.Core.Container.Type but also a
    assert %Container{} = container = Container.bind(Container.new(), SomeStructService)

    refute_receive {:building, SomeStructService}

    assert {:ok, %SomeStructService{}, %Container{}} =
             Container.pull(container, SomeStructService)

    assert_receive {:building, SomeStructService}
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

    assert {:ok, %SomeDependentStruct{}, %Container{} = new_container} =
             Container.pull(container, SomeDependentStruct)

    assert_receive {:building, SomeStructService}
  end

  test "a service value can be immediately set" do
    container =
      Container.new()
      |> Container.bind_impl(SomeStructService, %SomeStructService{})
      |> Container.bind(SomeDependentStruct)

    assert {:ok, %SomeDependentStruct{}, %Container{} = new_container} =
             Container.pull(container, SomeDependentStruct)

    refute_receive {:building, SomeStructService}
  end
end

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
      {:ok, %__MODULE__{}}
    end
  end

  test "a service module can be registered and pulled" do
    # When a single atom is registered, it is considered as a utype (a userland
    # abstract type). Given we do not provide an implementation, the container
    # expects that it is not only a Tonka.Core.Container.Type but also a
    assert %Container{} = container = Container.register(Container.new(), SomeStructService)

    assert {:ok, %SomeStructService{}, %Container{} = new_container} =
             Container.pull(container, SomeStructService)
  end
end

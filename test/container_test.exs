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
  end

  test "a service module can be registered" do
    # When a single atom is registered, it is considered as a utype (a
    # userland abstract type)
    container = Container.new()
    assert %Container{} = container = Container.register(container, SomeStructService)
  end
end

defmodule Tonka.PeopleTest do
  use ExUnit.Case, async: true

  alias Tonka.Data.Person
  alias Tonka.Data.People
  alias Tonka.Core.Container

  test "basic people api" do
    container =
      Container.new()
      |> Container.bind(People,
        params: %{
          "lud" => %{
            "dummy" => "hello"
          }
        }
      )

    assert {:ok, container} = Container.prebuild_all(container)
    assert {:ok, people} = Container.pull_frozen(container, People)
    assert {:ok, lud} = People.fetch(people, "lud")
    assert ["default"] == lud.groups
    assert "lud" == lud.name
    # extra map keys are collected in :props
    assert "hello" == lud.props["dummy"]
  end
end

defmodule Tonka.PeopleTest do
  alias Tonka.Core.Container
  alias Tonka.Data.People
  alias Tonka.Data.Person
  use ExUnit.Case, async: true

  test "basic people api" do
    container =
      Container.new()
      |> Container.bind(People,
        params: %{
          "lud" => %{
            "dummy" => "hello"
          },
          "joe" => %{
            "other" => "value"
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

    assert {:ok, %{props: %{"dummy" => "hello"}}} = People.find_by(people, "dummy", "hello")
    assert {:ok, %{props: %{"other" => "value"}}} = People.find_by(people, "other", "value")
  end
end

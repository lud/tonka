defmodule Tonka.ProjectLoaderTest do
  use ExUnit.Case, async: true
  alias Tonka.Project.Loader
  import Tonka.Utils

  test "the base extension is always defined" do
    assert Tonka.Ext.BuiltIn in Tonka.Extension.list_extensions()
  end

  test "parsing a service with an unknown module" do
    raw =
      yaml!("""
      services:
        slack_api:
          use: this.module.is.unknown
          params:
            credentials: slack.bot
      """)

    raw |> IO.inspect(label: "raw")

    assert {:error, err} = Loader.get_definitions(raw)

    assert Exception.message(err) =~ ~r/no such service: this\.module\.is\.unknown/
    ## TODO Hugs needs to provide a way to get an error message as a simple string
    # assert find_error(err, )
  end

  test "definitions groups are always defined" do
    raw = %{}
    assert {:ok, definitions} = Loader.get_definitions(raw)
    assert Map.has_key?(definitions, :services)
    assert Map.has_key?(definitions, :publications)
  end

  test "parsing a service" do
    raw =
      yaml!("""
      services:
        slack_api:
          use: ext.slack.api
          params:
            credentials: slack.bot
      """)

    raw |> IO.inspect(label: "raw")

    assert {:ok, definitions} = Loader.get_definitions(raw)
    assert Map.has_key?(definitions, :services)
    assert Map.has_key?(definitions.services, "slack_api")
    assert Tonka.Ext.Slack.Services.SlackAPI == definitions.services["slack_api"].module
  end
end

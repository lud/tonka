defmodule Tonka.ProjectLoaderTest do
  use ExUnit.Case, async: true
  alias Tonka.Project.Loader
  import Tonka.Utils

  test "the base extension is always defined" do
    assert Tonka.Ext.BuiltIn in Tonka.Extension.list_extensions()
  end

  test "parsing a sample configuration" do
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

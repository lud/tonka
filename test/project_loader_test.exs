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

  test "parsing publications" do
    yaml = """
    publications:
      some_pub:
        grid:
          define_query:
            inputs:
              query_groups:
                origin: static
                static:
                  - limit: 2
                    query:
                      last_ext_username: lud-agi
                    title: TODO List
            module: core.query.mql.queries_groups_compiler
            params:
              data_type: issue
          issues_booklet:
            inputs:
              issues_groups:
                action: query_issues
                origin: action
            module: core.render.booklet.issues_groups
          query_issues:
            inputs:
              query_groups:
                action: define_query
                origin: action
            module: core.query.issues_groups_reader
          report_booklet:
            inputs:
              above:
                origin: static
                static:
                  - header: Issues Report
                  - mrkdwn: |-
                      Those issues may require your attention.
                      They require some work!
              below:
                origin: static
                static:
                  - mrkdwn: "Thank you for *reading* :ghost:"
              content:
                action: issues_booklet
                origin: action
            module: core.render.booklet_wrapper
            params:
              title: Issues Report
          report_to_slack:
            inputs:
              booklet:
                action: report_booklet
                origin: action
            module: ext.slack.publisher
            params:
              channel: DS4SX8VPF
              cleanup:
                key: devpost
    """

    raw = yaml!(yaml)
    assert {:ok, definitions} = Loader.get_definitions(raw)
    definitions |> IO.inspect(label: "definitions")
    assert Map.has_key?(definitions, :publications)
    assert Map.has_key?(definitions.publications, "some_pub")
    assert Map.has_key?(definitions.publications["some_pub"], :grid)

    Enum.each(definitions.publications, fn {id, v} ->
      assert v.id == id
    end)
  end
end

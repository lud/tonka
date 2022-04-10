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
            use: core.query.mql.queries_groups_compiler
            params:
              data_type: issue
          issues_booklet:
            inputs:
              issues_groups:
                action: query_issues
                origin: action
            use: core.render.booklet.issues_groups
          query_issues:
            inputs:
              query_groups:
                action: define_query
                origin: action
            use: core.query.issues_groups_reader
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
            use: core.render.booklet_wrapper
            params:
              title: Issues Report
          report_to_slack:
            inputs:
              booklet:
                action: report_booklet
                origin: action
            use: ext.slack.publisher
            params:
              channel: DS4SX8VPF
              cleanup:
                key: devpost
    """

    raw = yaml!(yaml)
    assert {:ok, definitions} = Loader.get_definitions(raw)
    assert Map.has_key?(definitions, :publications)
    assert Map.has_key?(definitions.publications, "some_pub")
    assert Map.has_key?(definitions.publications["some_pub"], :grid)

    Enum.each(definitions.publications, fn {pubid, pub} ->
      assert pub.id == pubid

      Enum.each(pub.grid, fn {actid, actdef} ->
        assert is_map(actdef.inputs)
        assert is_map(actdef.params)
        assert is_atom(actdef.module)
        assert is_list(actdef.module.module_info(:exports))
      end)
    end)
  end

  test "parsing the scheduler spec" do
    raw =
      yaml!("""
      scheduler:
        my_spec_1:
          schedule: "0 8 * * *"
          run:
            grid: "grid_1"
            input: none

        my_spec_2:
          backoff: 1h
          timezone: Europe/Paris
          schedule: "0 8 * * *"
          max_attempts: 2
          run:
            grid: "grid_1"
            input: none
      """)

    assert {:ok, definitions} = Loader.get_definitions(raw)
    assert Map.has_key?(definitions, :scheduler)
    assert is_list(definitions.scheduler)
    assert Enum.all?(definitions.scheduler, &is_struct(&1, Tonka.Project.Scheduler.Spec))

    s1 = Enum.find(definitions.scheduler, &(&1.id == "my_spec_1"))
    s2 = Enum.find(definitions.scheduler, &(&1.id == "my_spec_2"))

    assert 0 == s1.backoff
    assert 3600 * 1000 == s2.backoff

    assert "UTC" == s1.timezone
    assert "Europe/Paris" == s2.timezone

    assert 1 == s1.max_attempts
    assert 2 == s2.max_attempts

    assert is_struct(s1.schedule, Crontab.CronExpression)
    assert is_struct(s2.schedule, Crontab.CronExpression)
  end
end

defmodule Tonka.Demo do
  alias Tonka.Core.Container
  alias Tonka.Core.Grid
  import Container
  import Tonka.Utils
  require Logger

  def run do
    container = prepare_container()
    grid = prepare_grid()

    case Grid.run(grid, container, "some dummy input") do
      {:ok, :done, _grid} ->
        # grid |> IO.inspect(label: "grid", pretty: true)
        # grid.outputs |> IO.inspect(label: "grid.outputs")
        IO.puts("OK")

      {:error, detail, _grid} ->
        Logger.error(Grid.format_error(detail))
    end
  end

  def prepare_container do
    # On init, the project will fill the container with services used by actions.

    project_path = "var/projects/dev"

    container =
      new()
      |> bind(Tonka.Services.Credentials, &build_credentials(&1, project_path))
      |> bind(Tonka.Services.IssuesSource, Tonka.Ext.Gitlab.Services.Issues,
        params: %{
          "projects" => ["company-agilap/r-d/agislack", "pleenk/suivi"],
          "credentials" => "gitlab.private_token"
        }
      )
      |> bind(Tonka.Services.IssuesStore)
      |> bind(Tonka.Ext.Slack.Services.SlackAPI,
        params: %{
          "credentials" => "slack.bot"
        }
      )
      |> bind(Tonka.Services.CleanupStore)
      |> bind(Tonka.Services.ProjectStore)
      |> bind(Tonka.Services.ProjectStore.Backend, Tonka.Services.ProjectStore.CubDBBackend)

    {:ok, _issues_source, container} = pull(container, Tonka.Services.IssuesSource)

    case Container.prebuild_all(container) do
      {:ok, container} -> Container.freeze(container)
      {:error, e} -> raise e
    end
  end

  @spec build_credentials(Container.t(), binary) ::
          {:ok, Tonka.Services.Credentials.t(), Container.t()}
  defp build_credentials(c, project_path) do
    store =
      File.cwd!()
      |> Path.join("#{project_path}/credentials.json")
      |> Tonka.Services.Credentials.JsonFileCredentials.from_path!()

    {:ok, store, c}
  end

  def prepare_grid do
    Grid.new()
    |> Grid.add_action("define_query", Tonka.Actions.Queries.QueriesGroupsMQLCompiler,
      params: %{"data_type" => "issue"},
      inputs:
        Grid.pipe_static(
          %{},
          :query_groups,
          """
          - title: TODO List
            query:
              last_ext_username: 'lud-agi'
            limit: 2
          """
          |> yaml!()
        )
    )
    |> Grid.add_action("query_issues", Tonka.Actions.Queries.IssuesGroupsReader,
      inputs: Grid.pipe_action(%{}, :query_groups, "define_query")
    )
    |> Grid.add_action("issues_booklet", Tonka.Actions.Render.IssuesGroupsBookletRenderer,
      inputs: Grid.pipe_action(%{}, :issues_groups, "query_issues")
    )
    |> Grid.add_action("report_booklet", Tonka.Actions.Render.BookletWrapper,
      params: %{title: "Issues Report"},
      inputs:
        %{}
        |> Grid.pipe_action(:content, "issues_booklet")
        |> Grid.pipe_static(
          :above,
          """
          - header: Issues Report
          - mrkdwn: |-
              Those issues may require your attention.
              They require some work!
          """
          |> yaml!()
        )
        |> Grid.pipe_static(
          :below,
          """
          - mrkdwn: |-
              Thank you for *reading* :ghost:
          """
          |> yaml!()
        )
    )
    |> Grid.add_action("report_to_cli", Tonka.Actions.Render.BookletCliRenderer,
      inputs: Grid.pipe_action(%{}, :booklet, "report_booklet")
    )
    |> Grid.add_action("report_to_slatck", Tonka.Ext.Slack.Actions.SlackPublisher,
      inputs: Grid.pipe_action(%{}, :booklet, "report_booklet"),
      params: %{channel: "DS4SX8VPF"}
    )
  end
end

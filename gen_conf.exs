defmodule Sample do
  alias Tonka.Core.Container
  alias Tonka.Core.Grid
  alias Tonka.Data.ProjectInfo
  alias Tonka.Project.ProjectRegistry
  import Container
  import Tonka.Utils
  require Logger

  def big_fixture do
    %{container: prepare_container(), grid: prepare_grid()}
  end

  def prepare_container do
    # On init, the project will fill the container with services used by actions.

    project_path = "var/projects/dev"
    prk = "dev"
    service_sup_name = ProjectRegistry.via(prk, :service_sup)

    container =
      new()
      |> bind_impl(Tonka.Services.ServiceSupervisor, service_sup_name)
      |> bind_impl(
        ProjectInfo,
        ProjectInfo.new(prk: prk, storage_dir: Path.join(project_path, "storage"))
      )
      |> bind(Tonka.Services.Credentials, &build_credentials(&1, project_path))
      |> bind(Tonka.Services.IssuesSource, Tonka.Ext.Gitlab.Services.Issues,
        params: %{
          "projects" => ["my-company/r-d/my-awesome-project", "some-tool/suivi"],
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

    Container.freeze(container)
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
    |> Grid.add_action("report_to_slack", Tonka.Ext.Slack.Actions.SlackPublisher,
      inputs: Grid.pipe_action(%{}, :booklet, "report_booklet"),
      params: %{channel: "DS4SX8VPF", cleanup: %{"key" => "devpost"}}
    )
  end
end

%{container: container, grid: grid} = Sample.big_fixture()

Tonka.Core.ConfigGen.generate_config(container, [grid])
|> Ymlr.document!()
# |> Jason.encode!(pretty: true)
|> IO.puts()

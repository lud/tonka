defmodule Tonka.Demo do
  alias Tonka.Core.Container
  alias Tonka.Core.Grid
  import Container
  import Tonka.Utils
  require Logger

  def run do
    # -----------------------------------------------------------------------------
    #  Simulate a grid run from a job
    # -----------------------------------------------------------------------------

    # gitlab = issues_repository(params)
    # issues_source = issues_fetch_all(gitlab)
    # queries = map(params_groups, compile_mql)
    # issues = filter_issues(issues_source, query)
    # report = generate_report(issues, params)
    # target = team_member(name)
    # post = encode_slack_rich(report)
    # transport = slack(target)
    # post(transport, post)

    # TODO check the rate-limiter
    # TODO fake fetching the build container
    container = prepare_container()
    grid = prepare_grid()

    case Grid.run(grid, container, "some dummy input") do
      {:ok, :done, grid} ->
        # grid |> IO.inspect(label: "grid", pretty: true)
        # grid.outputs |> IO.inspect(label: "grid.outputs")
        IO.puts("OK")

      {:error, detail, grid} ->
        Logger.error(Grid.format_error(detail))
    end
  end

  def prepare_container do
    # On init, the project will fill the container with services used by actions.

    container =
      new()
      |> bind(Tonka.Services.Credentials, &build_credentials/1)
      |> bind(Tonka.Services.IssuesSource, Tonka.Ext.Gitlab.Services.Issues,
        params: %{
          "projects" => ["company-agilap/r-d/agislack"],
          "credentials" => "gitlab.private_token"
        }
      )
      |> bind(Tonka.Services.IssuesStore)

    {:ok, issues_source, container} = pull(container, Tonka.Services.IssuesSource)
    issues_source |> IO.inspect(label: "issues_source")

    {:ok, container} = Container.prebuild_all(container)
    Container.freeze(container)
  end

  @spec build_credentials(Container.t()) :: {:ok, Tonka.Services.Credentials.t(), Container.t()}
  defp build_credentials(c) do
    store =
      File.cwd!()
      |> Path.join("var/projects/dev/credentials.json")
      |> Tonka.Services.Credentials.JsonFileCredentials.from_path!()

    {:ok, store, c}
  end

  def prepare_grid do
    Grid.new()
    |> Grid.add_action("define_query", Tonka.Actions.Queries.CompileMQLGroups,
      params: %{"data_type" => "issue"},
      inputs:
        %{}
        |> Grid.pipe_static(
          :query_groups,
          """
          - title: TODO List
            query:
              labels: 'todo'
            limit: 2
          """
          |> yaml!()
        )
    )
    |> Grid.add_action("query_issues", Tonka.Actions.Queries.QueryIssuesGroups,
      inputs: %{} |> Grid.pipe_action(:query_groups, "define_query")
    )
    |> Grid.add_action("issues_booklet", Tonka.Actions.Render.BookletFromIssuesGroups,
      inputs: %{} |> Grid.pipe_action(:issues_groups, "query_issues")
    )
    |> Grid.add_action("report_booklet", Tonka.Actions.Render.WrapBooklet,
      inputs:
        %{}
        |> Grid.pipe_action(:content, "issues_booklet")
        |> Grid.pipe_static(:before, """

        """)
        |> Grid.pipe_static(:after, """

        """)
    )
  end
end

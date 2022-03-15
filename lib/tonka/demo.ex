defmodule Tonka.Demo do
  alias Tonka.Core.Container
  alias Tonka.Core.Container.Params

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

    # -- Project container initialization -----------------------------------------

    # On init, the project will fill the container with services used by operations.
    import Container

    container =
      new()
      |> bind(Tonka.Service.Credentials, fn c ->
        store =
          File.cwd!()
          |> Path.join("var/projects/dev/credentials.json")
          |> Tonka.Service.Credentials.JsonFileCredentials.from_path!()

        {:ok, store, c}
      end)
      |> IO.inspect(label: "container")
      |> bind(Tonka.Service.IssuesSource, Tonka.Ext.Gitlab.Issues,
        overrides:
          provide_params(Tonka.Ext.Gitlab.Issues, %{
            "projects" => ["company-agilap/r-d/agislack"],
            "credentials" => "gitlab.private_token"
          })
      )

    {:ok, creds, container} = pull(container, Tonka.Service.Credentials)
    {:ok, creds, container} = pull(container, Tonka.Service.IssuesSource)
    creds |> IO.inspect(label: "pulled", pretty: true)
  end

  defp provide_params(overrides \\ %{}, module, params) do
    Map.put(overrides, Params, fn ->
      case module.cast_params(params) do
        {:ok, params} -> {:ok, params}
        {:error, _} = err -> err
      end
    end)
  end
end

defmodule Tonka.Demo do
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

    alias Tonka.Core.Container

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

    # |> bind(Tonka.Service.IssuesSource, Tonka.Ext.Gitlab.Issues,
    #   # overrides the params for this service only. The defined types will only
    #   # be available for injection for the defined services, not its
    #   # dependencies
    #   overrides: %{
    #     Tonka.Params => fn c ->
    #       case Tonka.Ext.Gitlab.Issues.cast_params(%{"some" => "params"}) do
    #         {:ok, params} -> {:ok, params, c}
    #         {:error, _} = err -> err
    #       end
    #     end
    #   }
    # )

    {:ok, creds, container} = pull(container, Tonka.Service.Credentials)
    # {:ok, creds, container} = pull(container, Tonka.Service.IssuesSource)
    creds |> IO.inspect(label: "pulled", pretty: true)
  end
end

defmodule Tonka.Actions.Queries.QueryIssuesGroups do
  use Tonka.Core.Action

  def cast_params(term) do
    {:ok, term}
  end

  def configure(config) do
    config
    |> Action.use_input(:query_groups, Tonka.Actions.Queries.CompileMQLGroups.Return)
    |> Action.use_service(:issues_store, Tonka.Services.IssuesSource)
  end

  def call(inputs, injects, params) do
    injects |> IO.inspect(label: "injects")

    raise "do not use the issues sources here. Use an issue store on top of the issues source"

    issues = Tonka.Services.IssuesSource.fetch_all_issues(injects.issues_store)
  end
end

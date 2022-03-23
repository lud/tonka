defmodule Tonka.Actions.Queries.QueryIssuesGroups do
  use Tonka.Core.Action
  alias Tonka.Services.IssuesStore
  alias Tonka.Data.IssueGroup

  def cast_params(term) do
    {:ok, term}
  end

  def configure(config) do
    config
    |> Action.use_input(:query_groups, Tonka.Actions.Queries.CompileMQLGroups.Return)
    |> Action.use_service(:store, IssuesStore)
  end

  def call(inputs, injects, params) do
    Ark.Ok.map_ok(inputs.query_groups, fn group ->
      with {:ok, issues} <- IssuesStore.mql_query(injects.store, group.query, group.limit) do
        {:ok, IssueGroup.new(issues: issues, title: group.title)}
      end
    end)
  end
end

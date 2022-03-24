defmodule Tonka.Actions.Queries.QueryIssuesGroups do
  use Tonka.Core.Action
  alias Tonka.Services.IssuesStore
  alias Tonka.Data.IssuesGroup

  def cast_params(term) do
    {:ok, term}
  end

  def return_type, do: {:list, IssuesGroup}

  def configure(config) do
    config
    |> Action.use_input(:query_groups, Tonka.Actions.Queries.CompileMQLGroups.Return)
    |> Action.use_service(:store, IssuesStore)
  end

  def call(%{query_groups: query_groups}, %{store: store}, _params) do
    Ark.Ok.map_ok(query_groups, fn group -> query_to_group(store, group) end)
  end

  defp query_to_group(store, %{query: query, limit: limit, title: title}) do
    # we will actually select all the issues, but only take the limit number, so
    # we can tell how much more there are
    with {:ok, issues} <- IssuesStore.mql_query(store, query, :infinity) do
      len = length(issues)
      issues = Enum.take(issues, limit)
      remain = len - limit
      {:ok, IssuesGroup.new(issues: issues, title: title, remain: remain)}
    end
  end
end

defmodule Tonka.Actions.Queries.QueryIssuesGroups do
  use Tonka.Core.Action

  def cast_params(term) do
    {:ok, term}
  end

  def configure(config) do
    config
    |> Action.use_input(:query_groups, Tonka.Actions.Queries.CompileMQLGroups.Return)
  end

  def call(inputs, injects, params) do
    raise "inject issues store"
  end
end

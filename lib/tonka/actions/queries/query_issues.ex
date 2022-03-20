defmodule Tonka.Actions.Queries.QueryIssuesGroups do
  use Tonka.Core.Action

  def cast_params(term) do
    {:ok, term}
  end

  def configure(config, params) do
    config
    |> Action.use_input(:query_groups, Tonka.Actions.Queries.CompileMQLGroups.Return)
  end

  # input mql in Tonka.Data.MqlQuery

  # def inject_spec(params) do
  #   Action.inject()
  #   |> Action.use_service(My.Service, :mykey, required: false)
  #   |> Action.use_input(My.Input.Type, :other_key, required: false)
  # end

  def call(inputs, injects, params) do
    {:ok, []}
  end
end

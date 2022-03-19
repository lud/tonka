defmodule Tonka.Core.Action.QueryIssues do
  use Tonka.Core.Action

  @todo "move to Tonka.Act namespace"

  # input mql in Tonka.Data.MqlQuery

  # def inject_spec(params) do
  #   Action.inject()
  #   |> Action.use_service(My.Service, :mykey, required: false)
  #   |> Action.use_input(My.Input.Type, :other_key, required: false)
  # end

  def call(inputs, params, injects) do
    {:ok, []}
  end
end

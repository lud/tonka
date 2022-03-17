defmodule Tonka.Core.Operation.QueryIssues do
  use Tonka.Core.Operation

  # input mql in Tonka.Data.MqlQuery

  # def inject_spec(params) do
  #   Operation.inject()
  #   |> Operation.use_service(My.Service, :mykey, required: false)
  #   |> Operation.use_input(My.Input.Type, :other_key, required: false)
  # end

  def call(inputs, params, injects) do
    {:ok, []}
  end
end

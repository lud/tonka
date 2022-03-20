defmodule Tonka.Actions.Queries.CompileMql do
  use Tonka.Core.Action

  @params Hugs.build_props()
          |> Hugs.field(:data_type, type: {:enum, ["issue"]}, required: true)

  def cast_params(term) do
    Hugs.denormalize(term, @params)
  end

  def configure(config, params) do
    raise "todo configure #{inspect(__MODULE__)}"
  end
end

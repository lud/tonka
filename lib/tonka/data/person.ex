defmodule Tonka.Data.Person do
  @moduledoc """
  Represents a human person in a project
  """
  require Hugs

  Hugs.build_struct()
  |> Hugs.field(:id, type: :binary, required: true)
  |> Hugs.field(:name, type: :binary, generate: Hugs.Gen.copy("id"))
  |> Hugs.field(:groups, type: {:list, :binary}, default: ["default"])
  |> Hugs.field(:props, type: :map, generate: {__MODULE__, :collect_props, []})
  |> Hugs.define()

  @ignore_keys Enum.map(@__hugs_dfn.props.fields, fn {_, f} -> f.serkey end)

  @doc false
  def collect_props(ctx) do
    {:ok, Map.drop(ctx.parent_data, @ignore_keys)}
  end
end

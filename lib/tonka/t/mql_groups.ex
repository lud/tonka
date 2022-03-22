defmodule Tonka.T.MQLGroups do
  def cast_input(list) when is_list(list) do
    Ark.Ok.map_ok(list, &denormalize_group/1)
  end

  def cast_input(_other) do
    {:error, "not a list"}
  end

  @group_schema Hugs.build_props()
                |> Hugs.field(:limit, type: :integer)
                |> Hugs.field(:title, type: :binary)
                |> Hugs.field(:query, type: :map)

  defp denormalize_group(group) do
    Hugs.denormalize(group, @group_schema)
  end
end

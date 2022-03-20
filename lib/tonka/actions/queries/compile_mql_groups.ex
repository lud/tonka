defmodule Tonka.Actions.Queries.CompileMQLGroups do
  use Tonka.Core.Action

  @params Hugs.build_props()
          |> Hugs.field(:data_type, type: {:enum, ["issue"]}, required: true)

  def cast_params(term) do
    Hugs.denormalize(term, @params)
  end

  def configure(config, params) do
    config
    |> Action.use_input(:query_groups, Tonka.T.MQLGroups)
  end

  def call(%{query_groups: groups}, _, params) do
    with {:ok, as_atoms} <- list_keys_for_atoms(params.data_type) do
      Ark.Ok.map_ok(groups, fn group ->
        group |> IO.inspect(label: "group")

        with {:ok, compiled} <- Tonka.Core.Query.MQL.compile(group.query, as_atoms: as_atoms) do
          {:ok, Map.put(group, :query, compiled)}
        end
      end)
    end
  end

  @issue_binkeys Tonka.Util.TypeUtils.struct_binary_keys(Tonka.Data.Issue)

  defp list_keys_for_atoms("issues"), do: {:ok, @issue_binkeys}
  defp list_keys_for_atoms(_), do: {:ok, []}
end

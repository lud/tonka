defmodule Tonka.Actions.Queries.QueriesGroupsMQLCompiler do
  use Tonka.Core.Action

  # Ensure atom keys are loaded
  require Tonka.Data.Issue

  @params Hugs.build_props()
          |> Hugs.field(:data_type, type: {:enum, ["issue"]}, required: true)

  def cast_params(term) do
    Hugs.denormalize(term, @params)
  end

  def configure(config) do
    config
    |> Action.use_input(:query_groups, Tonka.Data.MQLGroups)
  end

  def return_type, do: __MODULE__.Return

  def call(%{query_groups: groups}, _, params) do
    with {:ok, as_atoms} <- list_keys_for_atoms(params.data_type) do
      Ark.Ok.map_ok(groups, fn group ->
        with {:ok, compiled} <- Tonka.Core.Query.MQL.compile(group.query, as_atoms: as_atoms) do
          {:ok, Map.put(group, :query, compiled)}
        end
      end)
    end
  end

  @issue_binkeys Tonka.Utils.struct_binary_keys(Tonka.Data.Issue)

  defp list_keys_for_atoms("issue"), do: {:ok, @issue_binkeys}
  defp list_keys_for_atoms("issues"), do: {:ok, @issue_binkeys}
  defp list_keys_for_atoms(_), do: {:ok, []}
end

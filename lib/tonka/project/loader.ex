defmodule Tonka.Project.Loader do
  @moduledoc """
  Transforms raw configuration data (obtained from a YAML file) into containers,
  grids, and other project data.
  """
  import Ark.Ok

  defmodule ServiceDef do
    require Hugs

    Hugs.build_struct()
    |> Hugs.field(:module, serkey: "use", type: :atom, cast: {__MODULE__, :resolve_module, []})
    |> Hugs.define()

    @doc false
    def resolve_module(_, _), do: {:ok, Tonka.Ext.Slack.Services.SlackAPI}
  end

  @type project_defs :: %{services: [ServiceDef.t()]}

  @spec get_definitions(map) :: {:ok, project_defs} | {:error, term}
  def get_definitions(map) when is_map(map) do
    with {:ok, services} <- get_services_defs(map) do
      {:ok, %{services: services}}
    end
  end

  defp get_services_defs(%{"services" => raw}) do
    map_ok(raw, fn {key, sdef} when is_binary(key) ->
      case ServiceDef.denormalize(sdef) do
        {:ok, service} -> {:ok, {key, service}}
        {:error, _} = err -> err
      end
    end)
    |> case do
      {:ok, v} -> {:ok, Map.new(v)}
      {:error, _} = err -> err
    end
  end

  defp get_services_defs(_), do: {:ok, %{}}
end

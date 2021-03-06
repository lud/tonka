defmodule Tonka.Project.Loader do
  @moduledoc """
  Transforms raw configuration data (obtained from a YAML file) into containers,
  grids, and other project data.
  """
  import Ark.Ok

  defmodule ServiceDef do
    require Hugs

    Hugs.build_struct()
    |> Hugs.field(:module,
      serkey: "use",
      type: :atom,
      cast: {__MODULE__, :resolve_module, []},
      required: true
    )
    |> Hugs.field(:params, type: :map, default: %{})
    |> Hugs.define()

    @doc false
    def resolve_module(bin, %{arg: %{resolver: services_map}}) do
      case Map.fetch(services_map, bin) do
        {:ok, mod} ->
          {:ok, mod}

        :error ->
          known = Enum.join(Map.keys(services_map), ", ")
          {:error, "no such service: #{bin}. Known services: #{known}"}
      end
    end
  end

  defmodule ActionDef do
    require Hugs

    Hugs.build_struct()
    |> Hugs.field(:inputs, type: :map, default: %{}, cast: {__MODULE__, :cast_inputs, []})
    |> Hugs.field(:module,
      serkey: "use",
      type: :atom,
      cast: {__MODULE__, :resolve_module, []},
      required: true
    )
    |> Hugs.field(:params, type: :map, default: %{})
    |> Hugs.define()

    @doc false
    def resolve_module(bin, %{arg: %{resolver: actions_map}}) do
      case Map.fetch(actions_map, bin) do
        {:ok, mod} ->
          {:ok, mod}

        :error ->
          known = Enum.join(Map.keys(actions_map), ", ")
          {:error, "no such action module: #{bin}. Known actions: #{known}"}
      end
    end

    @doc false
    def cast_inputs(map, _) when is_map(map) do
      Ark.Ok.reduce_ok(map, %{}, &cast_input/2)
    end

    def cast_inputs(other, _) do
      {:error, "expcted a map as inputs, got: #{inspect(other)}"}
    end

    def cast_input({input_name, inputdef}, acc) do
      with {:ok, input_key} <- Hugs.Cast.string_to_existing_atom(input_name),
           {:ok, inputspec} <- cast_input(inputdef) do
        {:ok, Map.put(acc, input_key, inputspec)}
      end
    end

    defp cast_input(%{"origin" => "static", "static" => static}),
      do: {:ok, %{origin: :static, static: static}}

    defp cast_input(%{"origin" => "action", "action" => action}) when is_binary(action),
      do: {:ok, %{origin: :action, action: action}}

    defp cast_input(%{"origin" => "grid_input"}),
      do: {:ok, %{origin: :grid_input}}

    defp cast_input(other),
      do: {:error, "invalid input defintion: #{other}"}
  end

  defmodule PublicationDef do
    require Hugs

    Hugs.build_struct()
    |> Hugs.field(:id, type: :binary, default: nil)
    |> Hugs.field(:grid, type: {:map, :binary, ActionDef}, required: true)
    |> Hugs.define()
  end

  @type project_defs :: %{
          services: %{binary => ServiceDef.t()},
          publications: %{binary => PublicationDef.t()}
        }

  @spec get_definitions(map) :: {:ok, project_defs} | {:error, :x}
  def get_definitions(map) when is_map(map) do
    with {:ok, services} <- get_services_defs(map),
         {:ok, publications} <- get_publications_defs(map) do
      {:ok, %{services: services, publications: publications}}
    end
  end

  defp get_services_defs(%{"services" => raw}) do
    service_index = Tonka.Extension.build_service_index()

    map_ok(raw, fn {key, sdef} when is_binary(key) ->
      case ServiceDef.denormalize(sdef, context_arg: %{resolver: service_index}) do
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

  defp get_publications_defs(%{"publications" => raw}) do
    action_index = Tonka.Extension.build_action_index()
    denorm_context = %{resolver: action_index}

    map_ok(raw, fn {key, pubdef} when is_binary(key) ->
      denormalize_pub(pubdef, key, denorm_context)
    end)
    |> case do
      {:ok, v} -> {:ok, Map.new(v)}
      {:error, _} = err -> err
    end
  end

  defp get_publications_defs(_), do: {:ok, %{}}

  defp denormalize_pub(pubdef, key, denorm_context) do
    case PublicationDef.denormalize(pubdef, context_arg: denorm_context) do
      {:ok, pub} -> {:ok, {key, Map.put(pub, :id, key)}}
      {:error, _} = err -> err
    end
  catch
    t, e -> {:error, {t, e}}
  end
end

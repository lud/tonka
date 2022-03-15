defmodule Tonka.Core.Injector do
  alias Tonka.Core.Container
  alias Tonka.Core.Container.InjectSpec

  def registered_injects(module, bucket) do
    Module.get_attribute(module, bucket, empty_bucket())
  end

  defp empty_bucket, do: []

  def register_inject(module, bucket, definition, key_from) when key_from in [:varname, :utype] do
    {bound_var, utype} = normalize_defintion(definition)

    key =
      case key_from do
        :varname -> varname(bound_var)
        :utype -> utype
      end

    register_inject(module, bucket, key, bound_var, utype)
  end

  def register_inject(module, bucket, key, bound_var, utype)
      when is_atom(bucket) and is_atom(key) do
    inject_list = registered_injects(module, bucket)

    case List.keyfind(inject_list, key, 0) do
      {_, _} ->
        {:error, %ArgumentError{message: "injected key #{inspect(key)} is already defined"}}

      nil ->
        inject = [bound_var: bound_var, utype: utype]
        inject_list = [{key, inject} | inject_list]
        Module.put_attribute(module, bucket, inject_list)
        :ok
    end
  end

  defp normalize_defintion({:in, _, [var, type]}) do
    {normalize_vardef(var), normalize_utype(type)}
  end

  defp normalize_vardef({varname, meta, nil}) when is_atom(varname) when is_list(meta) do
    varname
  end

  def normalize_utype({:__aliases__, _, _} = mod_type) do
    mod_type
  end

  def normalize_utype({:__MODULE__, _, _} = self_type) do
    self_type
  end

  def normalize_utype({:type, _} = native_type) do
    native_type
  end

  def normalize_utype({:collection, t}) do
    {:collection, normalize_utype(t)}
  end

  defp varname(varname) when is_atom(varname), do: varname

  def quoted_injects_map(injects) do
    input_vars =
      Enum.map(injects, fn {key, injected} ->
        bound_var = Keyword.fetch!(injected, :bound_var)
        {key, Macro.var(bound_var, nil)}
      end)

    quote do
      %{unquote_splicing(input_vars)}
    end
  end

  def expand_injects_to_quoted_map_typespec(inject_specs) do
    inject_specs
    |> Enum.map(fn {key, injected} ->
      utype =
        injected
        |> Keyword.fetch!(:utype)
        |> Tonka.Core.Injector.expand_type_to_quoted()

      {key, utype}
    end)
    |> then(&{:%{}, [], &1})
  end

  def expand_type_to_quoted(userland_type) do
    userland_type
    |> Tonka.Core.Container.expand_type()
    |> Tonka.Core.Container.to_quoted_type()
  end

  def build_injects(container, inject_specs, overrides \\ %{}) do
    Enum.reduce_while(
      inject_specs,
      {:ok, %{}, container},
      fn inject_spec, {:ok, map, container} ->
        case resolve_dep(inject_spec, map, container, overrides) do
          {:ok, _map, _container} = fine -> {:cont, fine}
          {:error, _} = err -> {:halt, err}
        end
      end
    )
  end

  defp resolve_dep(inject_spec, map, container, overrides) do
    case pull_override(overrides, inject_spec, map) do
      {:ok, map} -> {:ok, map, container}
      {:error, _} = err -> {:halt, err}
      :no_override -> pull_inject(container, inject_spec, map)
    end
  end

  defp pull_override(overrides, %InjectSpec{type: utype, key: key}, map)
       when is_map_key(overrides, utype) do
    override = Map.fetch!(overrides, utype)

    case call_override(override) do
      {:ok, value} -> {:ok, Map.put(map, key, value)}
      {:error, _} = err -> err
    end
  end

  defp pull_override(_, _, _) do
    :no_override
  end

  defp call_override(override) when is_function(override, 0) do
    override.()
  end

  defp pull_inject(container, %InjectSpec{type: utype, key: key}, map) do
    case Container.pull(container, utype) do
      {:ok, impl, new_container} ->
        new_map = Map.put(map, key, impl)
        {:ok, new_map, new_container}

      {:error, _} = err ->
        err
    end
  end
end

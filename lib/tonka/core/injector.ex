defmodule Tonka.Core.Injector do
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

  def normalize_utype({:type, t} = native_type) when is_atom(t) do
    native_type
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
end

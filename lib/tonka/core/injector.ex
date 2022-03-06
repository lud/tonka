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

    Enum.each(inject_list, fn sofar ->
      case Keyword.get(sofar, :key) do
        ^key -> raise ArgumentError, "injected key #{inspect(key)} is already defined"
        _ -> :ok
      end
    end)

    inject = [bound_var: bound_var, utype: utype]
    inject_list = [{key, inject} | inject_list]
    Module.put_attribute(module, bucket, inject_list)
    :ok
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

  def quoted_injects_map(module, bucket) do
    inject_list = registered_injects(module, bucket)

    input_vars =
      Enum.map(inject_list, fn {key, injected} ->
        bound_var = Keyword.fetch!(injected, :bound_var)
        {key, Macro.var(bound_var, nil)}
      end)

    quote do
      %{unquote_splicing(input_vars)}
    end
  end

  def quoted_injects_map_typedef(module, bucket, type_name) do
    # The container type (utype) is an AST fragment, but
    # expand_input_type_to_quoted/1 must be called with an actual value, not a
    # quoted form. So the call must take place in the generated code (the quote
    # block).

    inject_specs = registered_injects(module, bucket)

    quote bind_quoted: binding() do
      inject_types =
        inject_specs
        |> Enum.map(fn {key, injected} ->
          utype =
            injected
            |> Keyword.fetch!(:utype)
            |> Tonka.Core.Injector.expand_input_type_to_quoted()

          {key, utype}
        end)
        |> then(&{:%{}, [], &1})

      @type unquote(type_name)() :: unquote(inject_types)
    end
  end

  def expand_input_type_to_quoted(userland_type) do
    userland_type
    |> Tonka.Core.Container.expand_type()
    |> Tonka.Core.Container.to_quoted_type()
  end
end

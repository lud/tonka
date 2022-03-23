defmodule Tonka.Core.Booklet.Block do
  defmacro __using__(_) do
    quote location: :keep do
      Module.register_attribute(__MODULE__, :__prop, accumulate: true)
      @before_compile unquote(__MODULE__)
      import unquote(__MODULE__),
        only: [prop: 1, prop: 2]

      # validator must be defined ahead of module body so it can be properly
      # overriden.
      def validate_prop(key, value) do
        {:ok, value}
      end

      defoverridable validate_prop: 2
    end
  end

  defmacro prop(definition, options \\ [])

  defmacro prop(definition, options) when is_list(options) do
    property = {Macro.escape(definition), Macro.escape(options)}

    quote location: :keep do
      @__prop unquote(property)
    end
  end

  defmacro __before_compile__(env) do
    properties = Module.get_attribute(env.module, :__prop)

    {keys_opts, acceptors} =
      properties
      |> Enum.map(fn {definition, options} ->
        {key, quoted} = defun(definition)
        {{key, options}, quoted}
      end)
      |> Enum.unzip()

    {keys, _} = Enum.unzip(keys_opts)

    [
      def_new(),
      acceptors,
      acceptors_fallback(),
      keys_lists(keys),
      # We could build our own __struct__ implementation based on properties
      # requirements, but we will rather keep the default elixir behaviour. The
      # _accept_prop/2 function will be used by the Block module when casting a
      # 2-tuple to a struct.
      defstruct_block(keys_opts)
    ]
  end

  defp def_new() do
    quote location: :keep do
      def new(props \\ []) do
        Tonka.Core.Booklet.Block.cast_block!({__MODULE__, props})
      end
    end
  end

  defp keys_lists(keys) do
    quote location: :keep do
      def __props__() do
        unquote(keys)
      end
    end
  end

  defp defstruct_block(keys_opts) do
    enforce_keys = keys_opts |> Enum.filter(&required?/1) |> Enum.map(&elem(&1, 0))

    kv_defaults = [
      {:assigns, Macro.escape(%{})} | Enum.map(keys_opts, &as_defstruct_field/1)
    ]

    quote location: :keep do
      @enforce_keys unquote(enforce_keys)
      defstruct unquote(kv_defaults)
    end
  end

  defp required?({_key, opts}) do
    Keyword.get(opts, :required) == true
  end

  defp as_defstruct_field({key, opts}) do
    case Keyword.fetch(opts, :default) do
      {:ok, quoted_default} -> {key, quoted_default}
      :error -> {key, nil}
    end
  end

  # Define a property acceptor with a guard
  defp defun({:when, whenloc, [{key, _, _} = arg | guards]})
       when is_atom(key) do
    args = [key, arg]
    defun = {:when, whenloc, [{:_accept_prop, [], args} | guards]}

    quoted =
      quote location: :keep do
        # Define the function with the guard. If the guard passes, we pass to
        # validate_prop/2.
        def unquote(defun) do
          validate_prop(unquote(key), unquote(arg))
        end

        #  If the guard fails, we can already reject the value
        def _accept_prop(unquote(key), val) do
          {:error, {:bad_value, {unquote(key), val}}}
        end
      end

    {key, quoted}
  end

  defp defun({key, _, _}) when is_atom(key) do
    defun(key)
  end

  # Define a property acceptor without guard. We just pass to the validator.
  defp defun(key) when is_atom(key) do
    quoted =
      quote location: :keep do
        def _accept_prop(unquote(key), value) do
          validate_prop(unquote(key), value)
        end
      end

    {key, quoted}
  end

  defp acceptors_fallback do
    quote location: :keep do
      def _accept_prop(key, value) when is_atom(key) do
        {:error, %Tonka.Core.Booklet.CastError{reason: {:unknown_prop, __MODULE__, key, value}}}
      end

      def _accept_prop(key, value) do
        {:error, %Tonka.Core.Booklet.CastError{reason: {:bad_key, __MODULE__, key, value}}}
      end
    end
  end

  def cast_blocks(blocks) when is_list(blocks) do
    cast_blocks(blocks, [])
  end

  defp cast_blocks([block | blocks], acc) do
    case cast_block(block) do
      {:ok, block} -> cast_blocks(blocks, [block | acc])
      {:error, _} = err -> err
    end
  end

  defp cast_blocks([], acc) do
    {:ok, :lists.reverse(acc)}
  end

  def cast_block(%_struct{} = block) do
    {:ok, block}
  end

  def cast_block({module, props})
      when is_atom(module) and (is_list(props) or is_map(props)) do
    if function_exported?(module, :_accept_prop, 2) do
      reduce_props(props, module, [])
    else
      {:ok, struct!(module, props)}
    end
  end

  def cast_block!(block) do
    case cast_block(block) do
      {:ok, block} ->
        block

      {:error, %{__exception__: true} = e} ->
        raise e

      {:error, reason} ->
        raise "could not build block: #{inspect(reason)}"
    end
  end

  defp reduce_props([{k, v} | props], module, kvs) do
    case module._accept_prop(k, v) do
      {:ok, v} -> reduce_props(props, module, [{k, v} | kvs])
      {:error, _} = err -> err
    end
  end

  defp reduce_props([], module, kvs) do
    {:ok, struct!(module, kvs)}
  end
end

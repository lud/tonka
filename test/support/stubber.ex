defmodule Tonka.Test.Stubber do
  defmacro stub_funs(protocol) do
    quote bind_quoted: binding() do
      defs = protocol.__protocol__(:functions)

      Enum.each(defs, fn {function, arity} when arity >= 1 ->
        args = 1..(arity - 1) |> Enum.map(&Macro.var(:"arg#{&1}", nil))

        def unquote(function)(%{funs: funs} = state, unquote_splicing(args)) do
          Tonka.Test.Stubber.call_fun(funs, unquote(function), [state, unquote_splicing(args)])
        end
      end)
    end
  end

  def call_fun(funs, name, args) when is_map_key(funs, name) do
    fun = Map.fetch!(funs, name)
    apply(fun, args)
  end

  def call_fun(funs, name, args) do
    raise "funs do not define #{name}/#{length(args)}: #{inspect(funs)}"
  end
end

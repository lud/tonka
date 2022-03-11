defmodule Tonka.Core.StructDispatch do
  defmacro defdispatch(proto, do: block) do
    {:__block__, _, top_level} = block
    defs = Enum.filter(top_level, &(is_tuple(&1) and tuple_size(&1) == 3 and :def == elem(&1, 0)))

    any_defs =
      Enum.map(defs, fn {:def, _meta, [{function, _meta2, args}]} ->
        args = Enum.map(args, fn _ -> {:_, [], nil} end)

        quote do
          def unquote(function)(unquote_splicing(args)) do
            raise "#{inspect(unquote(proto))} must be derived"
          end
        end
      end)

    [
      quote location: :keep do
        defprotocol unquote(proto) do
          unquote(block)
        end
      end,
      quote location: :keep do
        errmsg = "#{inspect(unquote(proto))} must be derived"

        defimpl unquote(proto), for: Any do
          defs = unquote(Macro.escape(defs))

          defmacro __deriving__(module, struct, _options) do
            proto = unquote(proto)
            defs = unquote(Macro.escape(defs))

            quote location: :keep,
                  bind_quoted: [
                    proto: proto,
                    defs: Macro.escape(defs),
                    impl_mod: struct.__struct__,
                    module: module
                  ] do
              defimpl proto, for: module do
                Enum.each(defs, fn {:def, meta, [{function, meta2, args}]} ->
                  def unquote(function)(unquote_splicing(args)) do
                    unquote(impl_mod).unquote(function)(unquote_splicing(args))
                  end
                end)
              end
            end
          end

          unquote(any_defs)
        end
      end
    ]
  end
end

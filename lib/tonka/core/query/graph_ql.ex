defmodule Tonka.Core.Query.GraphQL do
  @format_schema NimbleOptions.new!(
                   pretty: [type: :boolean, default: false],
                   sort: [type: :boolean, default: false]
                 )

  require Record
  Record.defrecordp(:c, indent: 0, pretty: false, sort: false)

  def format_query(query, opts) when is_list(query) do
    ctx =
      opts
      |> NimbleOptions.validate!(@format_schema)
      |> base_context()

    [open_query(ctx), open_brace(ctx), format_subs(query, ctx), close_brace(ctx)]
    |> IO.inspect(label: "tokens")
    |> :erlang.iolist_to_binary()
    |> tap(&IO.puts/1)
  end

  defp base_context(opts) do
    c(pretty: !!opts[:pretty], sort: !!opts[:sort], indent: 0)
  end

  defp open_query(_ctx), do: "query"

  defp open_brace(c(pretty: true) = ctx), do: [" {", lf(ctx)]
  defp open_brace(c(pretty: false) = ctx), do: ["{", lf(ctx)]
  defp close_brace(c(pretty: true, indent: 0) = ctx), do: [indent(ctx), "}"]
  defp close_brace(c(pretty: true, indent: n) = ctx) when n > 0, do: [indent(ctx), "}", lf(ctx)]
  defp close_brace(c(pretty: false)), do: "}"

  defp indent(c(pretty: true, indent: n)), do: s_indent(n)
  defp indent(c(pretty: false)), do: ""

  defp s_indent(8), do: "                "
  defp s_indent(7), do: "              "
  defp s_indent(6), do: "            "
  defp s_indent(5), do: "          "
  defp s_indent(4), do: "        "
  defp s_indent(3), do: "      "
  defp s_indent(2), do: "    "
  defp s_indent(1), do: "  "
  defp s_indent(0), do: ""
  defp s_indent(n), do: String.duplicate("  ", n)

  defp lf(c(pretty: true)), do: ?\n
  defp lf(c(pretty: false)), do: 32

  defp indent_left(c(indent: n) = ctx) do
    c(ctx, indent: n + 1)
  end

  defp indent_right(c(indent: n) = ctx) do
    c(ctx, indent: n - 1)
  end

  defp format_subs(list, ctx) when is_list(list) do
    ctx = indent_left(ctx)
    list = sort_subs(list, ctx)

    Enum.map(list, fn
      bin when is_binary(bin) when is_atom(bin) ->
        [indent(ctx), format_field(bin), lf(ctx)]

      {field, subs} ->
        [
          indent(ctx),
          format_field(field),
          open_brace(ctx),
          format_subs(subs, ctx),
          close_brace(ctx)
        ]

      other ->
        raise ArgumentError, "unexepected sub item: #{inspect(other)}"
    end)
  end

  defp format_field(name) when is_binary(name), do: name
  defp format_field(name) when is_atom(name), do: Atom.to_string(name)

  defp sort_subs(list, c(sort: false)), do: list

  defp sort_subs(list, c(sort: true)) do
    Enum.sort_by(list, &sorter/1)
  end

  defp sorter(key) when is_binary(key), do: key
  defp sorter(key) when is_atom(key), do: Atom.to_string(key)
  defp sorter(tuple) when is_tuple(tuple), do: tuple |> elem(0) |> sorter()
end

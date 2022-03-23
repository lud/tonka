defmodule Tonka.Core.Query.GraphQL do
  @format_schema NimbleOptions.new!(
                   pretty: [type: :boolean, default: false],
                   sort: [type: :boolean, default: false]
                 )

  require Record
  Record.defrecordp(:c, indent: 0, pretty: false, sort: false)

  def format_query(query, opts \\ [])

  def format_query(query, opts) when is_list(query) do
    ctx =
      opts
      |> NimbleOptions.validate!(@format_schema)
      |> base_context()

    [open_query(ctx), open_brace(ctx), format_subs(query, ctx), close_brace(ctx)]
    |> :erlang.iolist_to_binary()
  end

  def format_query(query, opts) when is_tuple(query) do
    format_query([query], opts)
  end

  defp base_context(opts) do
    c(pretty: !!opts[:pretty], sort: !!opts[:sort], indent: 0)
  end

  defp open_query(_ctx), do: "query"

  defp open_brace(c(pretty: true) = ctx), do: [" {", lf(ctx)]
  defp open_brace(c(pretty: false) = ctx), do: ["{", lf(ctx)]
  defp close_brace(c(pretty: true) = ctx), do: [lf(ctx), indent(ctx), "}"]
  defp close_brace(c(pretty: false)), do: "}"

  defp indent(c(pretty: true, indent: n)), do: s_indent(n)
  defp indent(c(pretty: false)), do: []

  defp s_indent(8), do: "                "
  defp s_indent(7), do: "              "
  defp s_indent(6), do: "            "
  defp s_indent(5), do: "          "
  defp s_indent(4), do: "        "
  defp s_indent(3), do: "      "
  defp s_indent(2), do: "    "
  defp s_indent(1), do: "  "
  defp s_indent(0), do: []
  defp s_indent(n), do: String.duplicate("  ", n)

  defp lf(c(pretty: true)), do: ?\n
  defp lf(c(pretty: false)), do: []
  defp separator(c(pretty: true)), do: ?\n
  defp separator(c(pretty: false)), do: 32

  defp indent_left(c(indent: n) = ctx) do
    c(ctx, indent: n + 1)
  end

  defp format_subs(list, ctx) when is_list(list) do
    ctx = indent_left(ctx)
    list = sort_subs(list, ctx)

    list
    |> Stream.scan({nil, nil}, fn
      sub, {_, prev} ->
        sep =
          case requires_separator_after(prev, ctx) do
            true -> [separator(ctx)]
            false -> []
          end

        {[sep, format_sub(sub, ctx)], sub}
    end)
    |> Enum.map(&elem(&1, 0))
  end

  defp requires_separator_after(nil, _) do
    false
  end

  defp requires_separator_after(_, c(pretty: true)) do
    true
  end

  defp requires_separator_after(prev, _) do
    requires_separator_after(prev)
  end

  defp requires_separator_after(prev) do
    not is_tuple(prev)
  end

  defp format_sub(sub, ctx) when is_binary(sub) when is_atom(sub),
    do: [indent(ctx), format_field(sub)]

  defp format_sub({field, []}, ctx) do
    format_sub(field, ctx)
  end

  defp format_sub({field, subs}, ctx) do
    [
      indent(ctx),
      format_field(field),
      open_brace(ctx),
      format_subs(subs, ctx),
      close_brace(ctx)
    ]
  end

  defp format_sub({field, args, subs}, ctx) do
    [
      indent(ctx),
      format_field(field),
      format_args(args, ctx),
      open_brace(ctx),
      format_subs(subs, ctx),
      close_brace(ctx)
    ]
  end

  defp format_field(name) when is_binary(name), do: name
  defp format_field(name) when is_atom(name), do: Atom.to_string(name)

  defp format_args(nil, _), do: []
  defp format_args([], _), do: []
  defp format_args(map, _) when map_size(map) == 0, do: []

  defp format_args(args, ctx) when is_list(args) or is_map(args) do
    if is_list(args) and not Keyword.keyword?(args) do
      raise ArgumentError, "invalid args: #{inspect(args)}"
    end

    mapped =
      args
      |> Enum.map(fn {k, v} -> [format_arg_key(k), format_colon(ctx), format_arg_val(v)] end)
      |> Enum.intersperse(32)

    [?(, mapped, ?)]
  end

  defp format_arg_key(key) when is_binary(key), do: key
  defp format_arg_key(key) when is_atom(key), do: Atom.to_string(key)

  # passing an atom ensures that there will be no quotes around the argument
  # value. other values are json_encoded
  defp format_arg_val(value) when is_atom(value), do: Atom.to_string(value)
  defp format_arg_val(value), do: Jason.encode!(value)

  defp format_colon(c(pretty: true)), do: ": "
  defp format_colon(_), do: ?:

  defp sort_subs(list, c(sort: false)), do: list

  defp sort_subs(list, c(sort: true)) do
    Enum.sort_by(list, &sorter/1)
  end

  defp sorter(key) when is_binary(key), do: key
  defp sorter(key) when is_atom(key), do: Atom.to_string(key)
  defp sorter(tuple) when is_tuple(tuple), do: tuple |> elem(0) |> sorter()
end

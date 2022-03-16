defmodule Tonka.Core.Query.MQL.Compiler do
  defmodule CompilationError do
    defexception [:message]
  end

  alias Tonka.Data.TimeInterval

  @type opt :: {:as_atoms, :all | :existing | [binary]}
  @type opts :: [opt]

  @virtual_prop_operators ~w($size)

  @date_operators_bin ~w($date_lt)
  @date_operators_a Enum.map(@date_operators_bin, &String.to_atom/1)

  # Unary operators are operators that accept a value
  @unary_operators_bin Enum.concat([
                         ~w($eq $gt $gte $in $lt $lte $nin),
                         @virtual_prop_operators,
                         @date_operators_bin
                       ])

  # Object operators are operators that expect a sub object to work with
  @object_operators_bin ~w($and $not $or $size $subset $elem_match) ++ @virtual_prop_operators

  @known_ops_bin (@unary_operators_bin -- @object_operators_bin) ++ @object_operators_bin

  @opts_b2a Enum.into(@known_ops_bin, %{}, fn bin -> {bin, String.to_atom(bin)} end)

  def unary_operators(:binary), do: @unary_operators_bin
  def object_operators(:binary), do: @object_operators_bin
  def date_operators(:atom), do: @date_operators_a

  # Options
  #
  # - `as_atoms` – `:all`, `:existing` or a list of binary keys. Binary keys
  #   matching that option will be casted to atoms when compiling the query.
  #   This allows to use the query to match on maps or structs with atom keys.
  #   `:all` means that we use `String.to_atom/1`, `:existing` means that we use
  #   `String.to_existing_atom/1` and fail otherwise. A list of binary keys will
  #   also use `String.to_existing_atom/1` and fail with `:badarg` if the atom
  #   does not exist.  For obvious reasons this option should only be use
  #   internally.
  #
  def compile!(q, opts \\ []) when is_map(q) and is_list(opts) do
    opts = cast_opts(opts)
    comp(q, opts)
  end

  defp cast_opts(opts) do
    opts
    |> Keyword.put_new(:as_atoms, [])
    |> Map.new()
  end

  defp comp(m, opts) when is_map(m) do
    Map.new(Enum.map(m, &comp(&1, opts)))
  end

  defp comp({"$subset", %{"filter" => filter, "match" => match}}, opts) do
    {:"$subset", %{filter: comp(filter, opts), match: comp(match, opts)}}
  end

  defp comp({"$subset", v}, _opts) do
    raise CompilationError, "invalid $subset definition, got: #{inspect(v)}"
  end

  defp comp({k, v}, _opts) when k in ~w($date_lt) do
    if is_binary(v) do
      {:"$date_lt", {:compiled, parse_date_or_interval(v)}}
    else
      raise CompilationError, "a binary value is required for #{k}, got: #{inspect(v)}"
    end
  end

  defp comp({"$" <> _ = special, v}, opts) when special in @known_ops_bin do
    {Map.fetch!(@opts_b2a, special), comp(v, opts)}
  end

  defp comp({"$" <> _ = unknown, _v}, _opts) do
    raise CompilationError, "unknown MQL operator: $#{unknown}"
  end

  defp comp({k, v}, opts) when is_atom(k) do
    {k, comp(v, opts)}
  end

  defp comp({k, v}, %{as_atoms: :all} = opts) when is_binary(k) do
    {String.to_atom(k), comp(v, opts)}
  end

  defp comp({k, v}, %{as_atoms: :existing} = opts) when is_binary(k) do
    {String.to_existing_atom(k), comp(v, opts)}
  end

  defp comp({k, v}, %{as_atoms: list} = opts) when is_binary(k) do
    sub = comp(v, opts)

    if k in list do
      {String.to_existing_atom(k), sub}
    else
      {k, sub}
    end
  end

  defp comp(v, _opts)
       when is_binary(v)
       when is_integer(v)
       when is_atom(v)
       when is_float(v),
       do: v

  defp comp([], _), do: []
  defp comp([h | t], opts), do: [comp(h, opts) | comp(t, opts)]

  defp comp(badarg, _) do
    raise CompilationError, """
    could not compile MQL element:

    #{inspect(badarg, pretty: true)}
    """
  end

  defp parse_date_or_interval(str) do
    with {:error, _} <- parse_date(str),
         {:error, _} <- TimeInterval.parse(str) do
      raise CompilationError,
            "could not parse #{inspect(str)} as DateTime or TimeInterval"
    else
      {:ok, data} -> data
    end
  end

  defp parse_date(str) do
    case DateTime.from_iso8601(str) do
      {:ok, date, _} -> {:ok, date}
      {:error, _} = err -> err
    end
  end
end

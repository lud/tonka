defmodule Tonka.Core.Reflection do
  @moduledoc """
  Helpers to extract information from language structures like modules or
  functions.
  """
  def implements_behaviour?(module, behaviour) do
    match_behaviour(behaviour, module.module_info(:attributes))
  end

  def match_behaviour(behaviour, [{:behaviour, [behaviour]} | _]), do: true
  def match_behaviour(behaviour, [_ | attrs]), do: match_behaviour(behaviour, attrs)
  def match_behaviour(_behaviour, []), do: false

  @doc """
  Returns the typespec of an existing, compiled function as described by the
  `Tonka.Core.Container` module.
  """
  @spec function_spec(module, atom, non_neg_integer) :: {tuple, term}
  def function_spec(module, function, arity)
      when is_atom(module) and is_atom(function) and is_integer(arity) and arity >= 0 do
    debug_info = find_chunk(module, :debug_info)
    dbgi_attribues = debug_info_attributes(debug_info)
    spec = find_function_spec(dbgi_attribues, module, function, arity)
    {:attribute, _, :spec, {{_, _}, funspec}} = spec
    [{:type, _, :fun, arg_ret_spec}] = funspec

    [{:type, _, :product, args}, return] = arg_ret_spec

    args = args |> Enum.map(&shrink_type/1) |> :erlang.list_to_tuple()
    return = shrink_type(return)
    {args, return}
  end

  defp shrink_type({:type, _, t, []}),
    do: t

  defp shrink_type({:type, _, :union, ts}),
    do: {:union, Enum.map(ts, &shrink_type/1)}

  defp shrink_type({:type, _, :tuple, ts}),
    do: {:tuple, Enum.map(ts, &shrink_type/1)}

  defp shrink_type({:atom, _, value}),
    do: {:atom, value}

  defp shrink_type({:type, _, :list, [param]}),
    do: {:list, shrink_type(param)}

  defp shrink_type({:remote_type, _, [{:atom, _, :elixir}, {:atom, 0, elixir_type}, []]}),
    do: elixir_type(elixir_type)

  defp elixir_type(:charlist),
    do: {:list, :char}

  defp find_function_spec(dbgi_attributes, module, function, arity) do
    found =
      Enum.find_value(dbgi_attributes, fn
        {:attribute, _lineno, :spec, {{^function, ^arity}, _}} = attr -> attr
        _ -> nil
      end)

    if found do
      found
    else
      raise ArgumentError,
            "function spec for #{inspect(module)}.#{function}/#{arity} could not be found"
    end
  end

  defp debug_info_attributes({:debug_info_v1, _dbgmod, {:elixir_v1, _map, attributes}}) do
    attributes
  end

  defp find_chunk(module, chunk) do
    case :code.which(module) do
      [] ->
        raise ArgumentError, "cannot retrieve beam file for #{module}"

      file ->
        case :beam_lib.chunks(file, [chunk]) do
          {:error, :beam_lib, reason} ->
            reason |> IO.inspect(label: "reason")
            raise "could not retrieve chunk #{inspect(chunk)} for #{module}"

          {:ok, {^module, [{^chunk, data}]}} ->
            data
        end
    end
  end

  defp struct_type(x, y) do
    {x, y}
  end
end

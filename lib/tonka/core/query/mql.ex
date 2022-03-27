defmodule Tonka.Core.Query.MQL do
  @moduledoc """
  MQL Stands for Map Query Language, a simple querying language inspired from
  MongoDB queries.
  """
  import Kernel, except: [match: 2]
  alias Tonka.Data.TimeInterval

  @type query :: map
  @type t :: map

  @spec compile!(query, __MODULE__.Compiler.opts()) :: t
  def compile!(q, opts \\ [])

  def compile!(q, opts) when is_map(q) and is_list(opts) do
    __MODULE__.Compiler.compile!(q, opts)
  end

  def compile!(other, _) do
    raise ArgumentError, message: "expected a query, got: #{inspect(other)}"
  end

  @spec compile(query, __MODULE__.Compiler.opts()) :: {:ok, t} | {:error, term}
  def compile(q, opts \\ []) when is_map(q) and is_list(opts) do
    {:ok, compile!(q, opts)}
  rescue
    e in __MODULE__.Compiler.CompilationError -> {:error, e}
  end

  # defguard is_struct(v, s) when is_map_key(v, :__struct__) and :erlang.map_get(:__struct__, v) == s

  defguard is_enum(v) when is_list(v) or is_map(v)

  defguard is_scalar(q)
           when is_binary(q) or is_atom(q) or is_integer(q) or is_float(q)

  # Alias to local function without "?"
  def match?(query, map), do: match(query, map)

  defp match(q, m) when is_map(q) and is_map(m) when is_enum(q),
    do: Enum.all?(q, &match(&1, m))

  defp match({:"$not", q}, v),
    do: not match(q, v)

  # With the $eq operator we do a soft comparison, so 1.0 and 1 will be equal
  defp match({:"$eq", alt}, v) when alt == v,
    do: true

  defp match({:"$eq", _}, _),
    do: false

  @num_comp_ops ~w($gt $gte $lt $lte)a

  defp match({act, n}, _) when act in @num_comp_ops and not is_number(n),
    do: raise("Expected a number with #{act}, got: #{inspect(n)}")

  defp match({act, _}, v) when act in @num_comp_ops and not is_number(v),
    # The BEAM can compare anything but we will stick to numbers
    do: false

  defp match({:"$gt", n}, v) when is_number(n) and is_number(v),
    do: v > n

  defp match({:"$gte", n}, v) when is_number(n) and is_number(v),
    do: v >= n

  defp match({:"$lt", n}, v) when is_number(n) and is_number(v),
    do: v < n

  defp match({:"$lte", n}, v) when is_number(n) and is_number(v),
    do: v <= n

  defp match({:"$in", candidates}, []) when is_list(candidates),
    do: false

  defp match({:"$in", candidates}, v) when is_list(v) and is_list(candidates),
    # Matching $in against a list
    do: intersects?(candidates, v)

  defp match({:"$in", candidates}, v) when is_list(candidates),
    do: Enum.member?(candidates, v)

  defp match({:"$in", badarg}, _),
    do: raise("Invalid value for $in, got: #{badarg}")

  defp match({:"$nin", []}, _),
    do: true

  defp match({:"$nin", candidates}, []) when is_list(candidates),
    do: true

  defp match({:"$nin", candidates}, v) when is_list(v) and is_list(candidates),
    do: not intersects?(candidates, v)

  defp match({:"$nin", candidates}, v) when is_list(candidates),
    do: not Enum.member?(candidates, v)

  defp match({:"$nin", badarg}, _),
    do: raise("Invalid value for $nin, got: #{badarg}")

  defp match({:"$or", sub_q}, v) when is_enum(sub_q),
    do: Enum.any?(sub_q, &match(&1, v))

  defp match({:"$or", badarg}, _),
    do: raise("Invalid value for $or, got: #{badarg}")

  defp match({:"$and", sub_q}, v) when is_enum(sub_q),
    do: Enum.all?(sub_q, &match(&1, v))

  defp match({:"$and", badarg}, _),
    do: raise("Invalid value for $and, got: #{badarg}")

  defp match({:"$size", q}, v) when is_list(v),
    do: match(q, length(v))

  defp match({:"$size", q}, v) when is_map(v),
    do: match(q, map_size(v))

  defp match({:"$size", _}, _),
    do: false

  # defp match({:"$subset", _}, v) when not is_enum(v),
  #   do: false

  defp match({:"$subset", %{filter: qfilter, match: qmatch}}, v)
       when is_map(qfilter) and is_map(qmatch),
       do: run_subset(qfilter, qmatch, v)

  defp match({:"$subset", badarg}, _),
    do: raise("Invalid value for $subset, got: #{inspect(badarg)}")

  @date_operators __MODULE__.Compiler.date_operators(:atom)

  defp match({act, d} = kv, _v)
       when act in @date_operators and
              (not is_tuple(d) or elem(d, 0) != :compiled),
       do: raise("MQL Error: #{act} requires compilation, got: #{inspect(kv)}")

  # Matching for date when the value is not a date. We will return false,
  # but should we raise ?
  defp match({:"$date_lt", _}, v) when not is_struct(v, DateTime),
    do: false

  # Compare to an absolute time point
  defp match({:"$date_lt", {:compiled, %DateTime{} = d}}, v)
       when is_struct(d, DateTime),
       do: DateTime.compare(v, d) == :lt

  # Compare relative from now
  defp match({:"$date_lt", {:compiled, %TimeInterval{ms: ms}}}, v) do
    point = DateTime.add(DateTime.utc_now(), ms, :millisecond)
    match({:"$date_lt", {:compiled, point}}, v)
  end

  defp match({act, bad}, _v) when act in @date_operators,
    do: raise("MQL Error: #{act} did not match, got: #{inspect(bad)}")

  defp match({:"$elem_match", q}, v) when is_list(v),
    do: Enum.any?(v, &match(q, &1))

  defp match({:"$elem_match", q}, v) when is_map(v),
    do: match({:"$elem_match", q}, Map.values(v))

  defp match({:"$elem_match", _}, _),
    do: false

  defp match({k, nil}, m) when not is_map_key(m, k),
    do: true

  defp match({k, q}, m) when is_map_key(m, k) do
    v = Map.fetch!(m, k)
    match(q, v)
  end

  # Matching a raw value in query to a list of values in data. We return true
  # if the list contains the value
  defp match(q, list) when is_scalar(q) and is_list(list),
    do: Enum.member?(list, q)

  defp match(v, v),
    # exact match
    do: true

  defp match(_query, _value) do
    false
  end

  defp run_subset(qfilter, qmatch, v) when is_map(v),
    do: run_subset(qfilter, qmatch, Map.values(v))

  defp run_subset(qfilter, qmatch, v) when is_list(v) do
    filtered = Enum.filter(v, &match(qfilter, &1))
    match(qmatch, filtered)
  end

  # @optimize Would be MapSet
  defp intersects?(list_a, list_b),
    do: list_a != list_a -- list_b

  @doc """
  Returns a parameterized schema that validates a raw query (where special keys
  like `$and` are still binaries) for the given type.

  This function is intended for internal use and is expected to work with flat
  schemas, i.e. it will only use the top-level property names from the schema.
  """
  def query_schema(%{"type" => "object", "properties" => %{} = properties}) do
    prop_keys = Map.keys(properties)
    unary_ops = __MODULE__.Compiler.unary_operators(:binary)
    object_ops = __MODULE__.Compiler.object_operators(:binary)

    # match a litteral value

    %{
      "type" => "object",
      "anyOf" => [
        def_ref("property_matches"),
        def_ref("top_level_ops")
      ],
      "definitions" => %{
        "base_value" => %{"type" => ~w(null integer array boolean string)},
        "property_matches" => %{
          "type" => "object",
          "patternProperties" => %{
            pattern_list(prop_keys) => %{
              "anyOf" => [
                def_ref("base_value"),
                def_ref("prop_level_ops")
              ]
            }
          }
        },
        "top_level_ops" => %{
          "type" => "object",
          "patternProperties" => %{
            pattern_list(object_ops) => %{
              "anyOf" => [
                def_ref("top_level_ops"),
                def_ref("property_matches")
              ]
            }
          }
        },
        "prop_level_ops" => %{
          "type" => "object",
          "patternProperties" => %{
            pattern_list(unary_ops) => def_ref("base_value"),
            pattern_list(object_ops) => %{
              "anyOf" => [
                def_ref("prop_level_ops"),
                def_ref("property_matches")
              ]
            }
          }
        }
      }
    }
  end

  defp pattern_list(operators) do
    "^(" <> Enum.join(operators, "|") <> ")$"
  end

  defp def_ref(name) do
    %{"$ref" => "#/definitions/#{name}"}
  end
end

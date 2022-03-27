defmodule Tonka.Services.CleanupStore do
  alias Tonka.Services.ProjectStore
  alias Tonka.Services.CleanupStore.Hashable
  alias __MODULE__

  defmodule CleanupParams do
    require Hugs

    Hugs.build_struct()
    |> Hugs.field(:key, type: :binary, required: true)
    |> Hugs.field(:ttl, type: :integer, default: 0, cast: &Tonka.Data.TimeInterval.to_ms/1)
    |> Hugs.field(:inputs,
      type: {:list, :atom},
      default: [],
      cast: {:list, &Hugs.Cast.string_to_existing_atom/1}
    )
    |> Hugs.inject()
  end

  @type component :: binary() | atom()
  @type cleanup_params :: CleanupParams.t()
  @type inputs :: Action.inputs()
  @type key :: binary()
  @type cleanup_data :: term
  @type id :: integer
  @type ttl :: integer

  @enforce_keys [:pstore]
  defstruct @enforce_keys
  @type t :: %__MODULE__{pstore: ProjectStore.t()}

  def new(%ProjectStore{} = pstore) do
    %__MODULE__{pstore: pstore}
  end

  @spec compute_key(component, cleanup_params, inputs()) :: key
  def compute_key(component, %CleanupParams{key: topic} = params, inputs) do
    hashable_inputs = hashable_inputs(params.inputs, inputs)
    "#{component_name(component)}::#{topic}::#{compute_hash(hashable_inputs)}"
  end

  defp component_name(component) when is_binary(component),
    do: component

  defp component_name(component) when is_atom(component) do
    case Atom.to_string(component) do
      "Elixir." <> rest -> rest
      full -> full
    end
  end

  defp hashable_inputs(keys, inputs) do
    keys
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(fn key -> Map.fetch!(inputs, key) |> Hashable.hashable() end)
  end

  defp compute_hash(hashable_inputs) do
    :crypto.hash(:sha, hashable_inputs) |> Base.encode16()
  end

  @spec put(t, key, ttl, cleanup_data) :: :ok
  def put(%CleanupStore{pstore: ps}, key, ttl, cleanup_data)
      when is_binary(key) and is_integer(ttl) and is_map(cleanup_data) do
    ProjectStore.get_and_update(ps, __MODULE__, key, fn cleanups ->
      new_val =
        case cleanups do
          nil -> [{ttl, cleanup_data}]
          # we can prepend, only the ttl is important
          list -> [{ttl, cleanup_data} | list]
        end

      {nil, new_val}
    end)
    |> case do
      {:ok, nil} -> :ok
      other -> other
    end
  end

  @spec list_expired(t, key) :: [{id, cleanup_data}]
  def list_expired(t, key) when is_binary(key) do
    []
  end

  @spec delete_id(t, key, id) :: :ok
  def delete_id(t, key, id) when is_binary(key) and is_integer(id) do
  end
end

defprotocol Tonka.Services.CleanupStore.Hashable do
  @spec hashable(t) :: iodata()
  @doc """
  Returns a value that will be used to computes hashes for the cleanup store.
  """
  def hashable(t)
end

defimpl Tonka.Services.CleanupStore.Hashable, for: List do
  def hashable(list), do: Enum.map(list, &Tonka.Services.CleanupStore.Hashable.hashable/1)
end

defimpl Tonka.Services.CleanupStore.Hashable, for: BitString do
  # this does not actually support bitstrings, only binaries
  def hashable(string), do: string
end

defimpl Tonka.Services.CleanupStore.Hashable, for: Map do
  def hashable(map) do
    map
    |> Map.to_list()
    |> Tonka.Services.CleanupStore.Hashable.hashable()
  end
end

defimpl Tonka.Services.CleanupStore.Hashable, for: Tuple do
  def hashable(tuple) do
    tuple
    |> Tuple.to_list()
    |> Tonka.Services.CleanupStore.Hashable.hashable()
  end
end

defimpl Tonka.Services.CleanupStore.Hashable, for: Atom do
  def hashable(atom) do
    # Atoms supports utf8 in elixir, to not use to_charlist
    atom
    |> Atom.to_string()
    |> Tonka.Services.CleanupStore.Hashable.hashable()
  end
end

defimpl Tonka.Services.CleanupStore.Hashable, for: Integer do
  def hashable(int), do: int
end

defimpl Tonka.Services.CleanupStore.Hashable, for: Integer do
  def hashable(int) when int < 0 when int > 255 do
    int
    |> Integer.to_charlist()
    |> Tonka.Services.CleanupStore.Hashable.hashable()
  end

  def hashable(int),
    do: int
end

defimpl Tonka.Services.CleanupStore.Hashable, for: Float do
  def hashable(float) do
    float
    |> Float.to_charlist()
    |> Tonka.Services.CleanupStore.Hashable.hashable()
  end
end

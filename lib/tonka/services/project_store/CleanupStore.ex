defmodule Tonka.Services.CleanupStore do
  alias Tonka.Services.ProjectStore
  alias Tonka.Services.CleanupStore.Hashable

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

  @enforce_keys [:pstore]
  defstruct @enforce_keys
  @type t :: %__MODULE__{pstore: ProjectStore.t()}

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
    |> Enum.map(&(Map.fetch!(inputs, &1) |> Hashable.hashable()))
  end

  defp compute_hash(hashable_inputs) do
    :crypto.hash(:sha, hashable_inputs) |> Base.encode16()
  end

  @spec put_cleanup(t, key, cleanup_data) :: :ok
  def put_cleanup(t, key, cleanup_data) do
  end

  @spec list_cleanups(t, key) :: [{id, cleanup_data}]
  def list_cleanups(t, key) do
  end

  @spec delete_cleanup(t, key, id) :: :ok
  def delete_cleanup(t, key, id) do
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

defmodule Tonka.Services.CleanupStore do
  alias __MODULE__
  alias Tonka.Data.TimeInterval
  alias Tonka.Services.CleanupStore.Hashable
  alias Tonka.Services.ProjectStore
  alias Tonka.Core.Action

  use Tonka.Core.Service

  defmodule CleanupParams do
    require Hugs

    Hugs.build_struct()
    |> Hugs.field(:key, type: :binary, required: true)
    |> Hugs.field(:ttl, type: :integer, default: 0, cast: &TimeInterval.to_ms/1)
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

  @impl Service
  def cast_params(term) do
    {:ok, term}
  end

  @impl Service
  def configure(config) do
    config
    |> Service.use_service(:pstore, ProjectStore)
  end

  @spec compute_key(component, cleanup_params, inputs()) :: key
  def compute_key(component, %CleanupParams{key: topic} = params, inputs) do
    hashable_inputs = hashable_inputs(params.inputs, inputs)
    "#{component_name(component)}::#{topic}::#{compute_hash(hashable_inputs)}"
  end

  defp component_name(component) when is_binary(component),
    do: component

  defp component_name(component) when is_atom(component) do
    Tonka.Utils.module_to_string(component)
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
    expiration = now_ms() + ttl
    ps |> IO.inspect(label: "ps")

    ProjectStore.get_and_update(ps, __MODULE__, key, fn cleanups ->
      new_val =
        case cleanups do
          nil ->
            [{expiration, {0, cleanup_data}}]

          # we can prepend, only the expiration is important
          list ->
            id = max_id(list) + 1
            [{expiration, {id, cleanup_data}} | list]

          other ->
            raise "unexpected cub result: #{inspect(other)}"
        end

      {nil, new_val}
    end)
    |> case do
      {:ok, _} ->
        :ok

      other ->
        raise "unexpected cub result: #{inspect(other)}"
    end
  end

  defp max_id(entries) do
    ids = Enum.map(entries, fn {_, {id, _}} -> id end)
    Enum.max(ids)
  end

  @spec list_expired(t, key) :: [{id, cleanup_data}]
  def list_expired(%CleanupStore{pstore: ps}, key) when is_binary(key) do
    case ProjectStore.get(ps, __MODULE__, key, []) do
      [] ->
        []

      list ->
        now = now_ms()

        list
        |> Enum.filter(fn {exp, _} -> exp <= now end)
        |> Enum.map(&elem(&1, 1))
    end
  end

  @spec delete_id(t, key, id) :: :ok
  def delete_id(%CleanupStore{pstore: ps}, key, id) when is_binary(key) and is_integer(id) do
    ProjectStore.get_and_update(ps, __MODULE__, key, fn cleanups ->
      case filter_id(cleanups, id) do
        [] -> :pop
        rest -> {nil, rest}
      end
    end)
    |> case do
      {:ok, _} -> :ok
    end
  end

  defp now_ms, do: :erlang.system_time(:millisecond)

  defp filter_id(cleanups, id) do
    Enum.filter(cleanups, fn {_, {entry_id, _}} -> entry_id != id end)
  end
end

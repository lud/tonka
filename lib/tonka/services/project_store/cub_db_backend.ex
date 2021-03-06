defmodule Tonka.Services.ProjectStore.CubDBBackend do
  alias Tonka.Services.ProjectStore.Backend
  use Tonka.Core.Service
  alias Tonka.Services.ServiceSupervisor
  use Tonka.Project.ProjectLogger, as: Logger

  @derive Backend
  @enforce_keys [:cub]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(GenServer.server()) :: t()
  def new(cub) do
    %__MODULE__{cub: cub}
  end

  @impl Service
  def service_type,
    do: __MODULE__

  @impl Service
  def cast_params(term) do
    {:ok, term}
  end

  @impl Service
  def configure(config) do
    config
    |> use_service(:sup, ServiceSupervisor)
    |> use_service(:info, Tonka.Data.ProjectInfo)
  end

  @impl Service
  def build(%{sup: sup, info: %{storage_dir: dir, store_backend_name: name}}, _params) do
    start_ref(sup, name, dir)
  end

  def start_ref(sup, name, dir) do
    Logger.info("opening CubDB database at #{dir} as #{inspect(name)}")

    {ref, opts} =
      case name do
        nil -> {:use_pid, []}
        _ -> {name, [name: name]}
      end

    opts = opts ++ [data_dir: dir, auto_compact: true, auto_file_sync: true]

    child_spec = {CubDB, opts}

    with {:ok, pid} <- Supervisor.start_child(sup, child_spec) do
      ref =
        case ref do
          :use_pid ->
            pid

          _ ->
            ^pid = GenServer.whereis(name)
            name
        end

      {:ok, new(ref)}
    end
  end

  @spec put(t, Backend.prk(), Backend.component(), Backend.key(), Backend.value()) :: :ok
  def put(%{cub: cub}, _prk, component, key, value) do
    cub_key = {component, key}
    CubDB.put(cub, cub_key, value)
  end

  @spec get(t, Backend.prk(), Backend.component(), Backend.key()) :: Backend.value() | nil
  def get(%{cub: cub}, _prk, component, key) do
    cub_key = {component, key}
    CubDB.get(cub, cub_key, nil)
  end

  @spec delete(t, Backend.prk(), Backend.component(), Backend.key()) :: :ok
  def delete(%{cub: cub}, _prk, component, key) do
    cub_key = {component, key}
    CubDB.delete(cub, cub_key)
  end

  @spec get_and_update(
          t,
          Backend.prk(),
          Backend.component(),
          Backend.key(),
          Backend.getter_updater()
        ) :: {:ok, Backend.value()} | {:error, term}
  def get_and_update(%{cub: cub}, _prk, component, key, getter_updater) do
    cub_key = {component, key}
    CubDB.get_and_update(cub, cub_key, getter_updater)
  end
end

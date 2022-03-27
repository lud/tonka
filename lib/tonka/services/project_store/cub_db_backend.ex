defmodule Tonka.Services.ProjectStore.CubDBBackend do
  alias Tonka.Services.ProjectStore.Backend
  use Tonka.Core.Service

  @derive Backend
  @enforce_keys [:cub]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(GenServer.server()) :: t()
  def new(cub) do
    %__MODULE__{cub: cub}
  end

  @impl Service
  def cast_params(term) do
    {:ok, term}
  end

  def configure(config) do
    config
    |> use_service(:sup, Tonka.Services.ServiceSupervisor)
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

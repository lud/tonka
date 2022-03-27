defmodule Tonka.Services.ProjectStore.CubDBStore do
  alias Tonka.Services.ProjectStore.Backend

  @derive Backend
  @enforce_keys [:cub]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(GenServer.server()) :: t()
  def new(cub) do
    %__MODULE__{cub: cub}
  end

  @spec put(t, Backend.project_id(), Backend.component(), Backend.key(), Backend.value()) :: :ok
  def put(%{cub: cub}, _project_id, component, key, value) do
    cub_key = {component, key}
    CubDB.put(cub, cub_key, value)
  end

  @spec get(t, Backend.project_id(), Backend.component(), Backend.key()) :: Backend.value() | nil
  def get(%{cub: cub}, _project_id, component, key) do
    cub_key = {component, key}
    CubDB.get(cub, cub_key, nil)
  end

  @spec get_and_update(
          t,
          Backend.project_id(),
          Backend.component(),
          Backend.key(),
          Backend.getter_updater()
        ) :: {:ok, Backend.value()} | {:error, term}
  def get_and_update(%{cub: cub}, _project_id, component, key, getter_updater) do
    cub_key = {component, key}
    CubDB.get_and_update(cub, cub_key, getter_updater)
  end
end

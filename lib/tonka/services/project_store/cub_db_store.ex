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
  def get(%{cub: cub}, project_id, component, key) do
    cub_key = {component, key}
    CubDB.get(cub, cub_key, nil)
  end
end

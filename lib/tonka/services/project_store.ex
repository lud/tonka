import Ark.Interface

definterface Tonka.Services.ProjectStore.Backend do
  @type project_id :: String.t()
  @type component :: String.t()
  @type key :: String.t()
  @type value :: %{binary => Stirng.t() | integer | float | nil | value}
  @type getter_updater :: (value -> {value, value} | :pop)

  @spec put(t, project_id, component, key, value) :: :ok
  def put(t, project_id, component, key, value)

  @spec get(t, project_id, component, key) :: value | nil
  def get(t, project_id, component, key)

  @spec delete(t, project_id, component, key) :: :ok
  def delete(t, project_id, component, key)

  @spec get_and_update(t, project_id, component, key, getter_updater) ::
          {:ok, value} | {:error, term}
  def get_and_update(t, project_id, component, key, getter_updater)
end

defmodule Tonka.Services.ProjectStore do
  alias Tonka.Services.ProjectStore
  alias Tonka.Services.ProjectStore.Backend

  @enforce_keys [:project_id, :backend]
  defstruct @enforce_keys
  @todo "struct typings"
  @type t :: %__MODULE__{}

  defguard is_component(component) when is_binary(component) or is_atom(component)

  def new(project_id, backend) do
    %ProjectStore{project_id: project_id, backend: backend}
  end

  def put(%ProjectStore{project_id: project_id, backend: backend}, component, key, value)
      when is_component(component) and is_binary(key) and is_map(value) do
    component = cast_component(component)
    Backend.put(backend, project_id, component, key, value)
  end

  def get(%ProjectStore{project_id: project_id, backend: backend}, component, key, default \\ nil)
      when is_component(component) and is_binary(key) do
    component = cast_component(component)

    case Backend.get(backend, project_id, component, key) do
      nil -> default
      found -> found
    end
  end

  def delete(%ProjectStore{project_id: project_id, backend: backend}, component, key)
      when is_component(component) and is_binary(key) do
    component = cast_component(component)

    Backend.delete(backend, project_id, component, key)
  end

  def get_and_update(%ProjectStore{project_id: project_id, backend: backend}, component, key, f)
      when is_component(component) and is_function(f, 1) do
    component = cast_component(component)
    Backend.get_and_update(backend, project_id, component, key, f)
  end

  defp cast_component(c) when is_atom(c) do
    Tonka.Utils.module_to_string(c)
  end

  defp cast_component(c) when is_binary(c) do
    c
  end
end

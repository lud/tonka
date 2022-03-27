import Ark.Interface

defmodule Tonka.Services.ProjectStore do
  alias Tonka.Services.ProjectStore

  definterface Backend do
    @type project_id :: String.t()
    @type component :: String.t()
    @type key :: String.t()
    @type value :: %{binary => Stirng.t() | integer | float | nil | value}
    @type getter_updater :: (value -> {value, value})

    @spec put(t, project_id, component, key, value) :: :ok
    def put(t, project_id, component, key, value)

    @spec get(t, project_id, component, key) :: value | nil
    def get(t, project_id, component, key)

    @spec get_and_update(t, project_id, component, key, getter_updater) ::
            {:ok, value} | {:error, term}
    def get_and_update(t, project_id, component, key, getter_updater)
  end

  @enforce_keys [:project_id, :backend]
  defstruct @enforce_keys
  @todo "struct typings"
  @type t :: %__MODULE__{}

  def new(project_id, backend) do
    %ProjectStore{project_id: project_id, backend: backend}
  end

  def put(%ProjectStore{project_id: project_id, backend: backend}, component, key, value)
      when is_binary(component) and is_binary(key) and is_map(value) do
    Backend.put(backend, project_id, component, key, value)
  end

  def get(%ProjectStore{project_id: project_id, backend: backend}, component, key, default \\ nil)
      when is_binary(component) and is_binary(key) do
    case Backend.get(backend, project_id, component, key) do
      nil -> default
      found -> found
    end
  end

  def get_and_update(%ProjectStore{project_id: project_id, backend: backend}, component, key, f)
      when is_function(f, 1) do
    Backend.get_and_update(backend, project_id, component, key, f)
  end
end

import Ark.Interface

definterface Tonka.Services.ProjectStore.Backend do
  @type prk :: String.t()
  @type component :: String.t()
  @type key :: String.t()
  @type value :: %{binary => String.t() | integer | float | nil | value}
  @type getter_updater :: (value -> {value, value} | :pop)

  @spec put(t, prk, component, key, value) :: :ok
  def put(t, prk, component, key, value)

  @spec get(t, prk, component, key) :: value | nil
  def get(t, prk, component, key)

  @spec delete(t, prk, component, key) :: :ok
  def delete(t, prk, component, key)

  @spec get_and_update(t, prk, component, key, getter_updater) ::
          {:ok, value} | {:error, term}
  def get_and_update(t, prk, component, key, getter_updater)
end

defmodule Tonka.Services.ProjectStore do
  alias Tonka.Services.ProjectStore
  alias Tonka.Services.ProjectStore.Backend
  use TODO

  use Tonka.Core.Service

  @enforce_keys [:prk, :backend]
  defstruct @enforce_keys
  @todo "struct typings"
  @type t :: %__MODULE__{}

  defguard is_component(component) when is_binary(component) or is_atom(component)

  def new(prk, backend) do
    %ProjectStore{prk: prk, backend: backend}
  end

  @impl Service
  def cast_params(term) do
    {:ok, term}
  end

  @impl Service
  def configure(config) do
    config
    |> use_service(:backend, Tonka.Services.ProjectStore.Backend)
    |> use_service(:info, Tonka.Data.ProjectInfo)
  end

  @impl Service
  def build(%{backend: backend, info: %{prk: prk}}, _params) do
    {:ok, new(prk, backend)}
  end

  def put(%ProjectStore{prk: prk, backend: backend}, component, key, value)
      when is_component(component) and is_binary(key) and is_map(value) do
    component = cast_component(component)
    Backend.put(backend, prk, component, key, value)
  end

  def get(%ProjectStore{prk: prk, backend: backend}, component, key, default \\ nil)
      when is_component(component) and is_binary(key) do
    component = cast_component(component)

    case Backend.get(backend, prk, component, key) do
      nil -> default
      found -> found
    end
  end

  def delete(%ProjectStore{prk: prk, backend: backend}, component, key)
      when is_component(component) and is_binary(key) do
    component = cast_component(component)

    Backend.delete(backend, prk, component, key)
  end

  def get_and_update(%ProjectStore{prk: prk, backend: backend}, component, key, f)
      when is_component(component) and is_function(f, 1) do
    component = cast_component(component)
    Backend.get_and_update(backend, prk, component, key, f)
  end

  defp cast_component(c) when is_atom(c) do
    Tonka.Utils.module_to_string(c)
  end

  defp cast_component(c) when is_binary(c) do
    c
  end
end

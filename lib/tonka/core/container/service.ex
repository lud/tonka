defmodule Tonka.Core.Container.Service do
  alias __MODULE__
  alias Tonka.Core.Container.InjectSpec
  alias Tonka.Core.Container

  @type impl :: term
  @type service :: service(term)
  @type service(impl) :: {:ok, impl} | {:error, term}

  @callback service_type :: Tonka.Core.Container.typespec()
  @callback build_specs() :: [InjectSpec.t()]
  @callback build(map) :: {:ok, impl} | {:error, term}

  @enforce_keys [:built, :builder, :impl]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          built: boolean,
          builder: module,
          impl: term
        }

  def new(module) when is_atom(module) do
    %__MODULE__{built: false, builder: module, impl: nil}
  end

  def as_built(value) do
    %__MODULE__{built: true, builder: nil, impl: value}
  end

  def build(%Service{built: false, builder: builder} = service, container) do
    build_specs = build_specs(builder)

    with {:ok, injects, container} <- pull_inject_map(container, build_specs),
         {:ok, impl} <- init_builder(builder, injects) do
      service = %Service{service | impl: impl, built: true}
      {:ok, service, container}
    else
      {:error, _} = err -> err
    end
  end

  defp pull_inject_map(container, build_specs) do
    Enum.reduce_while(build_specs, {:ok, %{}, container}, fn
      inject_spec, {:ok, map, container} ->
        case pull_inject(container, inject_spec, map) do
          {:ok, _map, _container} = fine -> {:cont, fine}
          {:error, _} = err -> {:halt, err}
        end
    end)
  end

  defp pull_inject(container, %InjectSpec{type: utype, key: key}, map) do
    case Container.pull(container, utype) do
      {:ok, impl, new_container} ->
        new_map = Map.put(map, key, impl)
        {:ok, new_map, new_container}

      {:error, _} = err ->
        err
    end
  end

  defp build_specs(module) when is_atom(module) do
    module.build_specs()
  end

  defp init_builder(module, injects) when is_atom(module) do
    module.init(injects)
  end
end

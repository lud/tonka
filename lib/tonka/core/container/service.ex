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

  def build(%Service{built: false, builder: builder} = service, container) do
    build_specs = build_specs(builder)

    with {:ok, injects, container} <- build_inject_map(container, build_specs),
         {:ok, impl} <- init_builder(builder, injects) do
      service = %Service{service | impl: impl, built: true}
      {:ok, service, container}
    else
      {:error, _} = err -> err
    end
  end

  defp build_inject_map(container, build_specs) do
    Enum.reduce_while(build_specs, {:ok, %{}, container}, fn %InjectSpec{type: utype}, {map, c} ->
      case Container.pull(c, utype) do
        {:ok, impl, c2} -> {:cont, {:ok, {Map.put(map, utype, impl)}, c2}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp build_specs(module) when is_atom(module) do
    module.build_specs()
  end

  defp init_builder(module, injects) when is_atom(module) do
    module.init(injects)
  end
end

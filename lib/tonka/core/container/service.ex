defmodule Tonka.Core.Container.Service do
  alias __MODULE__
  alias Tonka.Core.Injector
  alias Tonka.Core.Container.InjectSpec
  alias Tonka.Core.Container

  @type impl :: term
  @type service :: service(term)
  @type service(impl) :: {:ok, impl} | {:error, term}
  @type container :: Container.t()
  @type builder :: module | (container -> {:ok, term, container} | {:error, term})

  @callback provides_spec :: Tonka.Core.Container.ReturnSpec.t()
  @callback inject_specs(
              function :: atom,
              arity :: non_neg_integer,
              arg_0n :: non_neg_integer
            ) :: [InjectSpec.t()]

  @callback init(map) :: service(term)

  @enforce_keys [:built, :builder, :impl]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          built: boolean,
          builder: module,
          impl: term
        }

  defmacro __using__(_) do
    quote location: :keep do
      import Tonka.Core.Container.Service.ServiceMacros
      Tonka.Core.Container.Service.ServiceMacros.init_module()
    end
  end

  def new(module) when is_atom(module) do
    %__MODULE__{built: false, builder: module, impl: nil}
  end

  def new(builder) when is_function(builder, 1) do
    %__MODULE__{built: false, builder: builder, impl: nil}
  end

  def as_built(value) do
    %__MODULE__{built: true, builder: nil, impl: value}
  end

  def build(%Service{built: false, builder: builder} = service, container)
      when is_atom(builder) do
    inject_specs = inject_specs(builder)

    with {:ok, injects, container} <- Injector.build_injects(container, inject_specs),
         {:ok, impl} <- init_builder(builder, injects) do
      service = %Service{service | impl: impl, built: true}
      {:ok, service, container}
    else
      {:error, _} = err -> err
    end
  end

  def build(%Service{built: false, builder: builder} = service, container)
      when is_function(builder, 1) do
    case builder.(container) do
      {:ok, impl, %Container{} = new_container} ->
        service = %Service{service | impl: impl, built: true}
        {:ok, service, new_container}

      {:error, _} = err ->
        err

      _ ->
        {:error, {:bad_return, builder, [container]}}
    end
  end

  def inject_specs(module) when is_atom(module) do
    module.inject_specs(:init, 1, 0)
  end

  defp init_builder(module, injects) when is_atom(module) do
    module.init(injects)
  end
end

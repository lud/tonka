defmodule Tonka.Core.Container.Service do
  alias __MODULE__
  alias Tonka.Core.Injector
  alias Tonka.Core.Container.InjectSpec
  alias Tonka.Core.Container

  @todo "overrides are not needed"

  @enforce_keys [:built, :builder, :impl, :overrides, :params]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          built: boolean,
          builder: module,
          impl: term,
          params: term
        }

  defmodule ServiceConfig do
    @enforce_keys [:injects]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            injects: [InjectSpec.t()]
          }

    def new do
      %__MODULE__{injects: []}
    end
  end

  @type impl :: term

  @type params :: term
  @type injects :: map
  @type config :: ServiceConfig.t()
  @callback cast_params(term) :: {:ok, params} | {:error, term}

  @doc """
  Returns the service configuration:
  * The list of other services types to inject

  The params are passed to that function as an help for development and testing.
  The returned configuration defines the parameters of the service init
  callback, those should not change depending on the params.
  """
  @callback configure(config, params) :: {:ok, config} | {:error, term}
  @callback init(injects, params) :: {:ok, impl} | {:error, term}

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour unquote(__MODULE__)
    end
  end

  def new(opts) do
    struct!(__MODULE__, opts)
  end

  @doc false
  def inject_specs(module) when is_atom(module) do
    module.inject_specs(:init, 1, 0)
  end

  # @use_service_options_schema NimbleOptions.new!()

  def use_service(%ServiceConfig{injects: injects} = cfg, key, utype) when is_atom(key) do
    spec = %InjectSpec{key: key, type: utype}
    injects = [spec | injects]
    %ServiceConfig{cfg | injects: injects}
  end

  # ---------------------------------------------------------------------------
  #  Building services
  # ---------------------------------------------------------------------------

  @spec build(t, Container.t()) :: {:ok, impl, Container.t()} | {:error, term}
  def build(%Service{built: true} = service, container),
    do: {:ok, service, container}

  def build(
        %Service{params: params, builder: module, overrides: overrides} = service,
        container
      )
      when is_atom(module) do
    # We do not store the casted params, because if we need to rebuild a service
    # we can just reuse the current struct by flipping the built flag to false.

    with {:ok, casted_params} <- call_cast_params(module, params),
         {:ok, %{injects: inject_specs}} <- call_config(module, casted_params),
         {:ok, injects, new_container} <- build_injects(container, inject_specs, overrides),
         {:ok, impl} <- init_module(module, injects, casted_params) do
      new_service = %Service{service | built: true, impl: impl}
      {:ok, new_service, new_container}
    else
      {:error, _} = err -> err
    end
  end

  defp call_builder(%Service{builder: function}, container)
       when is_function(function, 1) do
    case function.(container) do
      {:ok, impl, %Container{} = new_container} -> {:ok, impl, new_container}
      {:error, _} = err -> err
      other -> {:error, {:bad_return, {function, [container]}, other}}
    end
  end

  defp empty_config,
    do: ServiceConfig.new()

  defp call_cast_params(module, params) do
    case module.cast_params(params) do
      {:ok, _} = fine -> fine
      {:error, _} = err -> err
      other -> {:error, {:bad_return, {module, :cast_params, [params]}, other}}
    end
  end

  defp call_config(module, params) do
    empty = empty_config()

    case module.configure(empty_config(), params) do
      %ServiceConfig{} = config -> {:ok, config}
      other -> {:error, {:bad_return, {module, :configure, [empty, params]}, other}}
    end
  rescue
    # we do not want ok/error tuples in confiure() to keep the flow of the
    # config, so we have to rescue
    e -> {:error, e}
  end

  defp build_injects(container, inject_specs, overrides) do
    case Injector.build_injects(container, inject_specs, overrides) do
      {:ok, injects, new_container} -> {:ok, injects, new_container}
      {:error, _} = err -> err
    end
  end

  defp init_module(module, injects, params) when is_atom(module) do
    case module.init(injects, params) do
      {:ok, impl} -> {:ok, impl}
      {:error, _} = err -> err
      other -> {:error, {:bad_return, {module, :init, [injects]}, other}}
    end
  end
end

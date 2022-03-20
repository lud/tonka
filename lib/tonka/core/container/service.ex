defmodule Tonka.Core.Container.Service do
  alias __MODULE__
  alias Tonka.Core.Container.InjectSpec
  alias Tonka.Core.Container
  use TODO

  @enforce_keys [:built, :builder, :impl, :params, :name]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          name: nil | binary,
          built: boolean,
          builder: module,
          impl: term,
          params: term
        }

  defmodule ServiceConfig do
    @enforce_keys [:injects]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            injects: %{atom => InjectSpec.t()}
          }

    def new do
      %__MODULE__{injects: %{}}
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
  """
  @callback configure(config) :: config
  @callback init(injects, params) :: {:ok, impl} | {:error, term}

  defmacro __using__(_) do
    quote location: :keep do
      alias unquote(__MODULE__)
      @behaviour unquote(__MODULE__)
    end
  end

  def new(vars) do
    service = struct!(__MODULE__, vars)
    fun? = is_function(service.builder)

    if fun? and map_size(service.params) > 0,
      do: raise(ArgumentError, "params is only available for module-based services")

    service
  end

  @doc false
  def inject_specs(module) when is_atom(module) do
    module.inject_specs(:init, 1, 0)
  end

  # ---------------------------------------------------------------------------
  #  Configuration API
  # ---------------------------------------------------------------------------

  # @use_service_options_schema NimbleOptions.new!()

  def use_service(%ServiceConfig{injects: injects} = cfg, key, utype) when is_atom(key) do
    spec = %InjectSpec{key: key, type: utype}

    if Map.has_key?(injects, key) do
      raise ArgumentError, "service #{inspect(key)} is already configured"
    end

    %ServiceConfig{cfg | injects: Map.put(injects, key, spec)}
  end

  # ---------------------------------------------------------------------------
  #  Building services
  # ---------------------------------------------------------------------------

  @spec build(t, Container.t()) :: {:ok, impl, Container.t()} | {:error, term}
  def build(%Service{built: true} = service, container),
    do: {:ok, service, container}

  def build(
        %Service{params: params, builder: module} = service,
        container
      )
      when is_atom(module) do
    # We do not store the casted params, because if we need to rebuild a service
    # we can just reuse the current struct by flipping the built flag to false.

    with {:ok, casted_params} <- call_cast_params(module, params),
         {:ok, %{injects: inject_specs}} <- call_configure(module),
         {:ok, {injects, new_container}} <- Container.build_injects(container, inject_specs),
         {:ok, impl} <- init_module(module, injects, casted_params) do
      {:ok, as_built(service, impl), new_container}
    else
      {:error, _} = err -> err
    end
  end

  def build(%Service{builder: function} = service, container) when is_function(function, 1) do
    case function.(container) do
      {:ok, impl, %Container{} = new_container} -> {:ok, as_built(service, impl), new_container}
      {:error, _} = err -> err
      other -> {:error, {:bad_return, {function, [container]}, other}}
    end
  end

  defp as_built(service, impl) do
    %Service{service | built: true, impl: impl}
  end

  @doc false
  def base_config,
    do: ServiceConfig.new()

  defp call_cast_params(module, params) do
    case module.cast_params(params) do
      {:ok, _} = fine -> fine
      {:error, _} = err -> err
      other -> {:error, {:bad_return, {module, :cast_params, [params]}, other}}
    end
  end

  defp call_configure(module) do
    base = base_config()

    case module.configure(base_config()) do
      %ServiceConfig{} = config ->
        {:ok, config}

      other ->
        {:error, {:bad_return, {module, :configure, [base]}, other}}
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

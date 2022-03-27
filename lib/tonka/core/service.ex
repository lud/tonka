defmodule Tonka.Core.Service do
  alias __MODULE__
  alias Tonka.Core.Container
  alias Tonka.Core.Container.InjectSpec
  use TODO

  @enforce_keys [:built, :builder, :impl, :params]
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
  @callback build(injects, params) :: {:ok, impl} | {:error, term}

  @new_opts [
    params: [
      type: :any,
      doc: """
      Params to be passed to the service `c:Tonka.Core.Service.cast_params/1` callback.
      Only used if the service is module-based.
      """,
      default: %{}
    ]
  ]
  @new_opts_schema NimbleOptions.new!(@new_opts)
  @new_opts_keys Keyword.keys(@new_opts)

  def new_opts_schema, do: @new_opts_schema
  def new_opts_keys, do: @new_opts_keys

  defmacro __using__(_) do
    quote location: :keep do
      alias unquote(__MODULE__)
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__), only: [use_service: 3]
    end
  end

  def new(builder, opts \\ []) do
    vars =
      opts
      |> NimbleOptions.validate!(@new_opts_schema)
      |> Keyword.put(:built, false)
      |> Keyword.put(:impl, nil)
      |> Keyword.put(:builder, builder)

    struct!(__MODULE__, vars)
  end

  def _new(vars) do
    service = struct!(__MODULE__, vars)
    fun? = is_function(service.builder)

    if fun? and map_size(service.params) > 0,
      do: raise(ArgumentError, "params is only available for module-based services")

    service
  end

  def from_impl(impl) do
    %__MODULE__{impl: impl, builder: nil, built: true, params: %{}}
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
         {:ok, impl} <- call_build(module, injects, casted_params) do
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

  defp call_build(module, injects, params) when is_atom(module) do
    case module.build(injects, params) do
      {:ok, impl} -> {:ok, impl}
      {:error, _} = err -> err
      other -> {:error, {:bad_return, {module, :init, [injects]}, other}}
    end
  end
end

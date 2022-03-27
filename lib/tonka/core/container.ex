defmodule Tonka.Core.Container do
  alias Tonka.Core.Container
  alias Tonka.Core.Container.InjectSpec
  alias Tonka.Core.Service
  use Tonka.Project.ProjectLogger, as: Logger
  use TODO

  @moduledoc """
  Implements a container for data structures or functions providing
  functionality to any `Tonka.Core.Action`.
  """

  @todo """
  Currently there is no typecheck at all on what an implementation returns.
  We could use TypeCheck to verifiy that implementations passed through
  bind_impl/3 or returned by Service.build/2 match the declared userland type.

  Although types are cool for generating typespecs but they are more aliases
  to available services provided by the tool than actual types.
  """

  defmodule ServiceResolutionError do
    defexception utype: nil, errkind: nil, selector: nil

    def message(%{utype: utype, errkind: errkind, selector: selector}) do
      "could not resolve service type #{inspect(utype)}" <>
        case selector do
          nil -> ""
          _ -> " with selector: #{inspect(selector)}"
        end <>
        ": " <>
        case errkind do
          :not_found -> "the service was not found"
          :build_frozen -> "the container is frozen"
          {:build_error, reason} -> "got error #{inspect(reason)} when building service"
        end
    end
  end

  @type typespec ::
          typealias
          | {:list, typespec}
          | {:remote_type, module, atom}
          | {:type, atom}
  @type typealias :: module

  @type builder :: module | (t -> {:ok, term, t} | {:error, term})
  @type override :: module | (() -> {:ok, term} | {:error, term})

  @type bind_impl_opt :: {:name, binary}
  @type bind_impl_opts :: [bind_impl_opt]
  @type bind_opt :: {:params, term}
  @type bind_opts :: list(bind_opt | bind_impl_opt)

  defguard is_builder(builder) when is_atom(builder) or is_function(builder, 1)
  defguard is_override(override) when is_function(override, 0)
  defguard is_utype(utype) when is_atom(utype)

  @enforce_keys [:services, :frozen]
  defstruct @enforce_keys

  @type t :: %Container{
          services: %{typespec => Service.t()},
          frozen: boolean
        }

  @spec new :: t()
  def new do
    struct!(Container, services: %{}, frozen: false)
  end

  @spec freeze(t) :: t()
  def freeze(%Container{} = c) do
    %Container{c | frozen: true}
  end

  @spec frozen?(t) :: boolean
  def frozen?(%Container{frozen: frozen?}) do
    !!frozen?
  end

  @bind_schema Service.new_opts_schema()
  @service_new_opts_keys Service.new_opts_keys()

  @spec bind(t, module) :: t
  def bind(%Container{} = c, utype) when is_atom(utype) do
    if has?(c, utype) do
      raise "service #{inspect(utype)} is already defined"
    end

    bind(c, utype, utype, [])
  end

  @spec bind(t, module, builder | bind_opts()) :: t

  def bind(%Container{} = c, utype, opts) when is_atom(utype) and is_list(opts) do
    if has?(c, utype) do
      raise "service #{inspect(utype)} is already defined"
    end

    bind(c, utype, utype, opts)
  end

  def bind(%Container{} = c, utype, builder) when is_utype(utype) and is_builder(builder),
    do: bind(c, utype, builder, [])

  @doc """
  Registers a new service builder in the container.

  ### Options

  #{NimbleOptions.docs(@bind_schema)}
  """
  @spec bind(t, typespec, builder(), bind_opts()) :: t
  def bind(%Container{frozen: true}, _, _, _) do
    raise "the container is frozen"
  end

  def bind(%Container{} = c, utype, builder, opts)
      when is_utype(utype) and is_builder(builder) and is_list(opts) do
    service = new_service(builder, opts)
    put_in(c.services[utype], service)
  end

  defp new_service(builder, opts) do
    opts =
      opts
      |> NimbleOptions.validate!(@bind_schema)
      |> Keyword.take(@service_new_opts_keys)

    Service.new(builder, opts)
  end

  @doc """
  Registers a new service implementation in the container.
  """
  @spec bind_impl(t, typespec, term) :: t
  def bind_impl(%Container{} = c, utype, impl) when is_utype(utype) do
    service = Service.from_impl(impl)

    put_in(c.services[utype], service)
  end

  def has?(%Container{} = c, utype) when is_utype(utype) do
    Map.has_key?(c.services, utype)
  end

  def has?(%Container{services: services}, utype) do
    Map.has_key?(services, utype)
  end

  def has_built?(%Container{} = c, utype) do
    case fetch_type(c, utype) do
      {:ok, %Service{built: true}} -> true
      _ -> false
    end
  end

  def pull(%Container{} = c, utype) when is_atom(utype) do
    Logger.debug("pulling service #{inspect(utype)}")

    case ensure_built(c, utype) do
      {:ok, c} -> {:ok, fetch_impl!(c, utype), c}
      {:error, _} = err -> err
    end
  end

  def pull_frozen(%Container{frozen: true} = c, utype) when is_atom(utype) do
    case pull(c, utype) do
      {:ok, value, _} -> {:ok, value}
      {:error, _} = err -> err
    end
  end

  def pull_frozen(%Container{frozen: false} = c, utype) when is_atom(utype) do
    c |> freeze() |> pull_frozen(utype)
  end

  def prebuild_all(%Container{services: services} = c) do
    Logger.info("prebuilding all services")
    unbuilt_utypes = for {key, %{built: false}} <- services, do: key
    Logger.debug("prebuilding unbuilt services: #{inspect(unbuilt_utypes)}")

    case Ark.Ok.reduce_ok(unbuilt_utypes, c, fn utype, new_c -> ensure_built(new_c, utype) end) do
      {:ok, new_c} ->
        Logger.info("✓ successfully prebuilt all services")
        {:ok, new_c}

      {:error, _} = err ->
        err
    end
  end

  def ensure_built(%{frozen: frozen} = c, utype) do
    service = fetch_type(c, utype)

    case service do
      {:ok, %Service{built: true}} ->
        Logger.debug("service #{inspect(utype)} is already built")
        {:ok, c}

      {:ok, %Service{built: false}} when frozen ->
        Logger.error("service #{inspect(utype)} is not built but the container is frozen")
        {:error, %ServiceResolutionError{utype: utype, errkind: :build_frozen}}

      {:ok, %Service{built: false} = service} ->
        Logger.debug("service #{inspect(utype)} is not built")
        build_service(c, utype, service)

      :error ->
        {:error, %ServiceResolutionError{utype: utype, errkind: :not_found}}
    end
  end

  defp fetch_type(%{services: services}, utype) do
    Map.fetch(services, utype)
  end

  defp fetch_impl!(c, utype) do
    {:ok, %Service{built: true, impl: impl}} = fetch_type(c, utype)
    impl
  end

  # ---------------------------------------------------------------------------
  #  Building services
  # ---------------------------------------------------------------------------

  defp build_service(c, utype, service) do
    Logger.debug("building service #{inspect(utype)} with #{inspect(service.builder)}")

    case Service.build(service, c) do
      {:ok, %Service{built: true} = new_service, %Container{} = new_c} ->
        Logger.info("✓ successfully built service #{inspect(utype)}")

        replace_service(new_c, utype, service, new_service)

      {:error, _} = err ->
        err
    end
  end

  defp replace_service(%{services: services} = c, utype, service, %{built: true} = built_service) do
    ^service = Map.fetch!(services, utype)
    services = Map.put(services, utype, built_service)

    {:ok, %Container{c | services: services}}
  end

  def build_injects(%Container{} = c, inject_specs) do
    Ark.Ok.reduce_ok(inject_specs, {%{}, c}, &pull_inject/2)
  end

  defp pull_inject({key, %InjectSpec{type: utype, key: key}}, {map, container}) do
    case Container.pull(container, utype) do
      {:ok, impl, new_container} ->
        new_map = Map.put(map, key, impl)
        {:ok, {new_map, new_container}}

      {:error, _} = err ->
        err
    end
  end

  def build_injects_frozen(%Container{frozen: true} = c, inject_specs) do
    Ark.Ok.reduce_ok(
      inject_specs,
      %{},
      fn {key, %InjectSpec{type: utype, key: key}}, map ->
        case Container.pull(c, utype) do
          {:ok, impl, ^c} -> {:ok, Map.put(map, key, impl)}
          {:error, _} = err -> err
        end
      end
    )
  end
end

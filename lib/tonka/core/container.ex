defmodule Tonka.Core.Container do
  alias Tonka.Core.Container
  alias Tonka.Core.Injector
  alias Tonka.Core.Container.Service
  alias Tonka.Core.Container.InjectSpec
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
          | {:collection, typespec}
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

  @common_bind_opts [
    name: [
      type: {:or, [{:in, [nil]}, :string]},
      doc: """
      When set, defines a named service that can be found
      by its name.
      """,
      default: nil
    ]
  ]

  @bind_schema NimbleOptions.new!(
                 @common_bind_opts ++
                   [
                     params: [
                       type: :any,
                       doc: """
                       Params to be passed to the service `c:Tonka.Core.Container.Service.cast_params/1` callback.
                       Only used if the service is module-based.
                       """,
                       default: %{}
                     ]
                   ]
               )

  # TODO doc binding with a single utype with default opts, accepts only atoms and expects that
  # the utype is also a module.
  @spec bind(t, module) :: t
  def bind(%Container{} = c, utype) when is_atom(utype),
    do: bind(c, utype, utype, [])

  @spec bind(t, module, builder | bind_opts()) :: t

  # TODO doc binding with a single utype with given options, accepts only atoms
  # and expects that the utype is also a module.
  def bind(%Container{} = c, utype, opts) when is_atom(utype) and is_list(opts),
    do: bind(c, utype, utype, opts)

  # TODO doc binding with a utype and a builder with default opts, accepts only
  # atoms and expects that the utype is also a module.
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
    service = opts_to_service(opts, builder)
    put_in(c.services[utype], service)
  end

  defp opts_to_service(options, builder) do
    options
    |> NimbleOptions.validate!(@bind_schema)
    |> Keyword.put_new(:built, false)
    |> Keyword.put_new(:impl, nil)
    |> Keyword.put(:builder, builder)
    |> Service.new()
  end

  @bind_impl_schema NimbleOptions.new!(@common_bind_opts)

  @doc """
  Registers a new service implementation in the container.

  ### Options

  #{NimbleOptions.docs(@bind_impl_schema)}
  """

  @spec bind_impl(t, typespec, term, bind_impl_opts) :: t
  def bind_impl(%Container{} = c, utype, impl, opts \\ [])
      when is_utype(utype) and is_list(opts) do
    service =
      opts
      |> NimbleOptions.validate!(@bind_impl_schema)
      |> Keyword.merge(impl: impl, builder: nil, built: true, params: %{})
      |> Service.new()

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
    unbuilt_utypes = for {key, %{built: false}} <- services, do: key
    Ark.Ok.reduce_ok(unbuilt_utypes, c, fn utype, c -> ensure_built(c, utype) end)
  end

  def ensure_built(%{frozen: frozen} = c, utype) do
    case fetch_type(c, utype) do
      {:ok, %Service{built: true}} ->
        {:ok, c}

      {:ok, %Service{built: false}} when frozen ->
        {:error, %ServiceResolutionError{utype: utype, errkind: :build_frozen}}

      {:ok, %Service{built: false} = service} ->
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
    case Service.build(service, c) do
      {:ok, %Service{built: true} = new_service, %Container{} = new_c} ->
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

  # ---------------------------------------------------------------------------
  #  Container Types to Elixir Types expansion
  # ---------------------------------------------------------------------------

  @spec expand_type(typespec) :: {:type, atom} | {:remote_type, atom, atom}
  def expand_type(module) when is_atom(module) do
    IO.puts("expanding type: #{inspect(module)}")
    Code.ensure_loaded!(module)
    expand_type(module.expand_type())
  end

  def expand_type({:remote_type, module, type} = terminal)
      when is_atom(module) and is_atom(type) do
    terminal
  end

  def expand_type({:type, _} = terminal) do
    terminal
  end

  def expand_type({:collection, type}) do
    {:collection, expand_type(type)}
  end

  def to_quoted_type({:remote_type, module, type})
      when is_atom(module) and is_atom(type) do
    quote do
      unquote(module).unquote(type)
    end
  end

  def to_quoted_type({:type, type}) when is_atom(type) do
    quote do
      unquote(type)()
    end
  end

  def to_quoted_type({:type, {:atom, literal}}) when is_atom(literal) do
    quote do
      unquote(literal)
    end
  end

  def to_quoted_type({:collection, type}) do
    quote do
      [unquote(to_quoted_type(type))]
    end
  end
end

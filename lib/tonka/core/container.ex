defmodule Tonka.Core.Container do
  alias Tonka.Core.Container
  alias Tonka.Core.Container.Service
  use TODO

  @moduledoc """
  Implements a container for data structures or functions providing
  functionality to any `Tonka.Core.Operation`.
  """

  @todo """
  Currently there is no typecheck at all on what an implementation returns.
  We could use TypeCheck to verifiy that implementations passed through
  bind_impl/3 or returned by Service.build/2 match the declared userland type.

  Although types are cool for generating typespecs but they are more aliases
  to available services provided by the tool than actual types.
  """

  defmodule UnknownServiceError do
    defexception [:utype]

    def message(%{utype: utype}) do
      "unknown service #{inspect(utype)} in container"
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

  @type bind_opt :: {:overrides, %{typespec => override()}}
  @type bind_opts :: [bind_opt]

  defguard is_builder(builder) when is_atom(builder) or is_function(builder, 1)
  defguard is_override(override) when is_function(override, 0)
  defguard is_utype(utype) when is_atom(utype)

  @enforce_keys [:services, :frozen]
  defstruct @enforce_keys

  @type t :: %Container{
          services: %{typespec => Service.t()},
          frozen: boolean
        }

  def new do
    struct!(Container, services: %{}, frozen: false)
  end

  def freeze(%Container{} = c) do
    %Container{c | frozen: true}
  end

  @bind_options_schema NimbleOptions.new!(
                         params: [
                           type: :any,
                           doc: """
                           Params to be passed to the service `c:Tonka.Core.Container.Service.cast_params/1` callback.
                           Only used if the service is module-based.
                           """,
                           default: %{}
                         ],
                         overrides: [
                           type: {:custom, __MODULE__, :validate_overrides, []},
                           doc: """
                           A map of service type to services generator functions.
                           Genrator functions have an arity of `0`.
                           """,
                           default: %{}
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
  Registers a new service in the container.

  ### Options

  #{NimbleOptions.docs(@bind_options_schema)}
  """
  @spec bind(t, typespec, builder(), bind_opts) :: t
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
    |> NimbleOptions.validate!(@bind_options_schema)
    |> Keyword.put_new(:built, false)
    |> Keyword.put_new(:impl, nil)
    |> Keyword.put_new(:overrides, %{})
    |> Keyword.put(:builder, builder)
    |> Service.new()
  end

  @doc false
  def validate_overrides(overrides) do
    if not is_map(overrides) do
      {:error, "overrides must be a map"}
    else
      case Enum.reject(overrides, fn {_, v} -> is_override(v) end) do
        [] -> {:ok, overrides}
        [{k, v} | _] -> {:error, "invalid bind override for type #{inspect(k)}: #{inspect(v)}"}
      end
    end
  end

  def bind_impl(%Container{} = c, utype, value) when is_utype(utype) do
    options = [builder: :lol, impl: value, builder: nil, built: true, overrides: %{}, params: %{}]
    service = Service.new(options)
    put_in(c.services[utype], service)
  end

  def has?(%Container{} = c, utype) when is_utype(utype) do
    Map.has_key?(c.services, utype)
  end

  def pull(%Container{} = c, utype) when is_atom(utype) do
    case ensure_built(c, utype) do
      {:ok, c} -> {:ok, fetch_impl!(c, utype), c}
      {:error, _} = err -> err
    end
  end

  def ensure_built(%{frozen: frozen} = c, utype) do
    case fetch_type(c, utype) do
      {:ok, %Service{built: true}} -> {:ok, c}
      {:ok, %Service{built: false}} when frozen -> {:error, "the container is frozen"}
      {:ok, %Service{built: false} = service} -> build_service(c, utype, service)
      :error -> {:error, %UnknownServiceError{utype: utype}}
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

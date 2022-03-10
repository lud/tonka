defmodule Tonka.Core.Container do
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

  alias __MODULE__, as: C
  alias Tonka.Core.Container.Service

  @type typealias :: module

  @type f_params ::
          {typespec}
          | {typespec, typespec}
          | {typespec, typespec, typespec}
          | {typespec, typespec, typespec, typespec, typespec}
          | {typespec, typespec, typespec, typespec, typespec, typespec}
          | {typespec, typespec, typespec, typespec, typespec, typespec, typespec}
          | {typespec, typespec, typespec, typespec, typespec, typespec, typespec, typespec}

  @type function_spec :: {f_params, typespec}
  @type typespec :: typealias | function_spec | {:remote_type, module, atom} | {:type, atom}

  @type builder :: module | (t -> {:ok, term, t} | {:error, term})

  defguard is_builder(builder) when is_atom(builder) or is_function(builder, 1)
  defguard is_utype(utype) when is_atom(utype)

  defstruct [:services]

  @type t :: %__MODULE__{
          services: %{typespec => Service.builder()}
        }

  def new do
    struct!(__MODULE__, services: %{})
  end

  # on register/1 we accept only a module
  @spec bind(t, module) :: t
  def bind(%C{} = c, utype) when is_atom(utype) do
    bind(c, utype, utype)
    service = Service.new(utype)
    put_in(c.services[utype], service)
  end

  @spec bind(t, typespec, builder) :: t
  def bind(%C{} = c, utype, builder) when is_utype(utype) and is_builder(builder) do
    service = Service.new(builder)
    put_in(c.services[utype], service)
  end

  def bind_impl(%C{} = c, utype, value) when is_utype(utype) do
    service = Service.as_built(value)
    put_in(c.services[utype], service)
  end

  def has?(%C{} = c, utype) when is_utype(utype) do
    Map.has_key?(c.services, utype)
  end

  def pull(%C{} = c, utype) when is_atom(utype) do
    case ensure_built(c, utype) do
      {:ok, c} -> {:ok, fetch_impl!(c, utype), c}
      {:error, _} = err -> err
    end
  end

  def ensure_built(c, utype) do
    case fetch_type(c, utype) do
      {:ok, %Service{built: true}} -> {:ok, c}
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

  defp build_service(c, utype, %{built: false} = service) do
    case Service.build(service, c) do
      {:ok, built_service, c} -> replace_service(c, utype, service, built_service)
      {:error, _} = err -> err
    end
  end

  defp replace_service(%{services: services} = c, utype, service, built_service) do
    ^service = Map.fetch!(services, utype)
    services = Map.put(services, utype, built_service)

    {:ok, %C{c | services: services}}
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

  def expand_type({:type, type} = terminal) when is_atom(type) do
    terminal
  end

  defp raise_invalid_type(module) do
    # implements? = Tonka.Core.Reflection.implements_behaviour?(module, Tonka.Core.Container.Type)

    raise "module #{inspect(module)} does not define expand_type/0"
    # raise """
    # module #{inspect(module)} does not define expand_type/0

    # #{if not implements? do
    #   "#{inspect(module)} does not implement the #{inspect(Tonka.Core.Container.Type)} behaviour"
    # end}
    # """
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
end

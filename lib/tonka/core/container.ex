defmodule Tonka.Core.Container do
  alias Tonka.Core.Injector
  alias Tonka.Core.Container.InjectSpec
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

  @type bind_opt :: {:overrides, %{typespec => builder()}}
  @type bind_opts :: [bind_opt]

  defguard is_builder(builder) when is_atom(builder) or is_function(builder, 1)
  defguard is_override(override) when is_function(override, 0)
  defguard is_utype(utype) when is_atom(utype)

  defstruct [:services]

  @type t :: %Container{
          services: %{typespec => Service.t()}
        }

  def new do
    struct!(Container, services: %{})
  end

  # TODO doc binding with a single utype with default opts, accepts only atoms and expects that
  # the utype is also a module.
  @spec bind(t, module) :: t
  def bind(%Container{} = c, utype) when is_atom(utype),
    do: bind(c, utype, utype, [])

  # TODO doc binding with a single utype with given options, accepts only atoms
  # and expects that the utype is also a module.
  @spec bind(t, module, bind_opts()) :: t
  def bind(%Container{} = c, utype, opts) when is_atom(utype) and is_list(opts),
    do: bind(c, utype, utype, opts)

  # TODO doc binding with a utype and a builder with default opts, accepts only
  # atoms and expects that the utype is also a module.
  @spec bind(t, typespec, builder()) :: t
  def bind(%Container{} = c, utype, builder) when is_utype(utype) and is_builder(builder),
    do: bind(c, utype, utype, [])

  @spec bind(t, typespec, builder(), bind_opts) :: t
  def bind(%Container{} = c, utype, builder, opts)
      when is_utype(utype) and is_builder(builder) and is_list(opts) do
    options = cast_bind_opts(opts, builder)
    options |> IO.inspect(label: "options")
    service = Service.new([builder: builder] ++ options)
    put_in(c.services[utype], service)
  end

  defp cast_bind_opts(options, builder) do
    cast_info = %{builder: builder}

    options
    |> Enum.map(&validate_bind_opt!(&1, cast_info))
    |> with_default_opts()
    |> IO.inspect(label: "opts")
  end

  defp with_default_opts(opts) do
    opts
    |> Keyword.put_new(:built, false)
    |> Keyword.put_new(:impl, nil)
    |> Keyword.put_new(:overrides, %{})
  end

  defp validate_bind_opt!({:overrides, overrides}, %{builder: builder}) do
    overrides |> IO.inspect(label: "overrides")

    if not is_atom(builder) do
      raise ArgumentError,
            ":overrides bind option is only available for module-based services, got: #{inspect(builder)}"
    end

    if not is_map(overrides) do
      raise ArgumentError,
            "invalid value for bind option :overrides, expected a map, got: #{inspect(overrides)}"
    end

    case Enum.reject(overrides, fn {_, v} -> is_override(v) end) do
      [] ->
        :ok

      [{k, v} | _] ->
        raise ArgumentError, "invalid bind override at key #{inspect(k)}: #{inspect(v)}"
    end

    {:overrides, overrides}
  end

  defp validate_bind_opt!({key, _}, _) do
    raise "unknown bind option #{inspect(key)}"
  end

  @todo "support opts in bind_impl"

  def bind_impl(%Container{} = c, utype, value) when is_utype(utype) do
    options = [builder: :lol, impl: value, builder: nil, built: true, overrides: %{}]
    options |> IO.inspect(label: "options in impl")
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

  # ---------------------------------------------------------------------------
  #  Building services
  # ---------------------------------------------------------------------------

  defp build_service(c, utype, %Service{built: false} = service) do
    case call_builder(service, c) do
      {:ok, impl, %Container{} = new_c} ->
        new_service = %Service{service | impl: impl, built: true}
        replace_service(new_c, utype, service, new_service)

      {:error, _} = err ->
        err
    end
  end

  defp call_builder(%Service{built: false, builder: module, overrides: overrides}, container)
       when is_atom(module) do
    with {:ok, injects, new_container} <- build_injects(container, module, overrides),
         injects |> IO.inspect(label: "injects"),
         {:ok, impl} <-
           init_module(module, injects) do
      {:ok, impl, new_container}
    else
      {:error, _} = err -> err
    end
  end

  defp call_builder(function, container) when is_function(function, 1) do
    case function.(container) do
      {:ok, impl, %Container{} = new_container} -> {:ok, impl, new_container}
      {:error, _} = err -> err
      other -> {:error, {:bad_return, {function, [container]}, other}}
    end
  end

  defp build_injects(container, module, overrides) do
    inject_specs = Service.inject_specs(module)

    case Injector.build_injects(container, inject_specs, overrides) do
      {:ok, injects, new_container} -> {:ok, injects, new_container}
      {:error, _} = err -> err
    end
  end

  defp apply_overrides(injects, %Service{overrides: overrides}) do
    Map.merge(injects, overrides)
  end

  defp init_module(module, injects) when is_atom(module) do
    case module.init(injects) do
      {:ok, impl} -> {:ok, impl}
      {:error, _} = err -> err
      other -> {:error, {:bad_return, {module, :init, [injects]}, other}}
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

defmodule Tonka.Core.Container.Service.ServiceMacros do
  alias Tonka.Core.Injector
  alias Tonka.Core.Container.InjectSpec
  alias Tonka.Core.Container.ReturnSpec
  alias Tonka.Core.Container.Service

  @init_called :__tonka_service_init_called
  @inject_specs :__tonka_service_inject_specs
  @provides_called :__tonka_service_provides_called
  @provides_type :__tonka_service_provides_type
  @forced_provides :__tonka_service_forced_typedef_typespec

  @doc false
  defmacro init_module do
    Module.put_attribute(__CALLER__.module, @init_called, false)
    Module.put_attribute(__CALLER__.module, @provides_called, false)

    quote location: :keep do
      import unquote(__MODULE__), only: :macros

      @behaviour Service
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro inject(definition) do
    if Module.get_attribute(__CALLER__.module, @init_called) do
      raise("cannot declare inject after init")
    end

    case Injector.register_inject(
           __CALLER__.module,
           @inject_specs,
           definition,
           :varname
         ) do
      :ok -> nil
      {:error, badarg} -> raise badarg
    end

    nil
  end

  defmacro provides(typedef) do
    typedef = Injector.normalize_utype(typedef)
    _provides(__CALLER__, typedef)
  end

  defmacro provides(typedef, forced_typespec) do
    typedef = Injector.normalize_utype(typedef)
    _provides(__CALLER__, {@forced_provides, typedef, forced_typespec})
  end

  def _provides(caller, typedef) do
    if Module.get_attribute(caller.module, @init_called) do
      raise("cannot declare inject after call")
    end

    if Module.get_attribute(caller.module, @provides_called) do
      raise("cannot declare provides twice")
    end

    Module.put_attribute(caller.module, @provides_called, true)
    Module.put_attribute(caller.module, @provides_type, typedef)

    nil
  end

  defmacro init(do: block) do
    if Module.get_attribute(__CALLER__.module, @init_called) do
      raise("cannot declare call twice")
    end

    Module.put_attribute(__CALLER__.module, @init_called, true)

    quote location: :keep, generated: true do
      # We use an attribute to store the code block so unquote() from the user
      # are already expanded when stored
      @__service_call_block unquote(Macro.escape(block, unquote: true))
    end
  end

  defmacro __before_compile__(env) do
    init_called = Module.get_attribute(env.module, @init_called)
    custom_init = Module.defines?(env.module, {:init, 1}, :def)
    provides_called = Module.get_attribute(env.module, @provides_called)
    custom_provides = Module.defines?(env.module, {:provides_spec, 0}, :def)

    if not (provides_called or custom_provides) do
      raise_no_provides(env.module)
    end

    if not (init_called or custom_init) do
      raise_no_init(env.module)
    end

    [
      def_injects(env),
      def_provides(env),
      if(Module.get_attribute(env.module, @init_called), do: def_init(env))
    ]
  end

  defp def_injects(env) do
    specs = Injector.registered_injects(env.module, @inject_specs)

    quote location: :keep, generated: true do
      @__built_inject_specs for {key, defn} <- unquote(specs),
                                do: %InjectSpec{key: key, type: defn[:utype]}

      @impl Service

      # the arguments to the inject_specs function define for which function +
      # arity the inject is made for.  the arg_0n parameter tells for to
      # argument of this function the injects should be passed on. This value is
      # the zero-based argument index.

      @spec inject_specs(
              function :: atom,
              arity :: non_neg_integer,
              arg_0n :: non_neg_integer
            ) :: [
              InjectSpec.t()
            ]

      @doc """
      Defines the dependencies.
      """
      def inject_specs(:init, 1, 0) do
        @__built_inject_specs
      end
    end
  end

  defp def_provides(env) do
    provides_type =
      case Module.get_attribute(env.module, @provides_type) do
        {@forced_provides, typedef, _} -> typedef
        typedef -> typedef
      end

    quote location: :keep do
      @impl Service
      @spec provides_spec :: ReturnSpec.t()
      def provides_spec do
        %ReturnSpec{type: unquote(provides_type)}
      end
    end
  end

  defp def_init(env) do
    provides_spec = Module.get_attribute(env.module, @provides_type)
    inject_specs = Injector.registered_injects(env.module, @inject_specs)
    inject_injects = Injector.quoted_injects_map(inject_specs)

    provides_spec =
      case provides_spec do
        {@forced_provides, a, b} -> {:{}, [], [:escaped_forced, a, Macro.escape(b)]}
        other -> other
      end

    quote location: :keep,
          generated: true,
          bind_quoted: [
            inject_specs: inject_specs,
            provides_spec: provides_spec,
            inject_injects: Macro.escape(inject_injects)
          ] do
      inject_type = Injector.expand_injects_to_quoted_map_typespec(inject_specs)
      @type inject_map :: unquote(inject_type)

      case provides_spec do
        {:escaped_forced, _, provides_type} ->
          @spec init(inject_map) :: Service.service(unquote(provides_type))

        _ ->
          provides_type =
            Service.ServiceMacros.maybe_expand_type_to_quoted(__MODULE__, provides_spec)

          @type provides :: unquote(provides_type)
          @spec init(inject_map) :: Service.service(provides)
      end

      @doc """
      Initializes the service.
      """
      @impl Service
      def init(unquote(inject_injects)) do
        unquote(@__service_call_block)
      end
    end
  end

  @doc false
  def maybe_expand_type_to_quoted(module, provides_spec) do
    Injector.expand_type_to_quoted(provides_spec)
  rescue
    e in ArgumentError ->
      IO.warn(e.message)

      case e.message do
        "could not load module" <> _ -> raise_circular_self(module, provides_spec)
        _ -> reraise e, __STACKTRACE__
      end
  end

  def raise_no_init(module) do
    raise """
    #{inspect(module)} must define the init/1 function

    For instance, with the init/1 macro:

        use Tonka.Core.Container.Service
        inject mydependency Some.In.Type

        init do
          mydependency + 1
        end
    """
  end

  def raise_no_provides(module) do
    raise """
    #{inspect(module)} must define a provided type

    For instance, with the provides/1 macro:

        use Tonka.Core.Container.Service
        provides Some.Out.Type
    """
  end

  def raise_circular_self(module, provides_spec) do
    code = Macro.to_string(provides_spec)

    raise """
    could not expand type #{code} provided by module #{inspect(module)}

    If a services provides its own module as a type alias, use the
    provides/2 macro instead of provides/1.


        use Tonka.Core.Container.Service
        inject mydependency Some.In.Type

        # define a custom type
        @type t :: %__MODULE__{}

        # add that custom type to the call to the provides macro
        provides __MODULE__, t
    """
  end
end

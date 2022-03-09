defmodule Tonka.Core.Container.Service.ServiceMacros do
  alias Tonka.Core.Injector
  alias Tonka.Core.Container.InjectSpec
  alias Tonka.Core.Container.ReturnSpec
  alias Tonka.Core.Container.Service

  defmacro init_module do
    Module.put_attribute(__CALLER__.module, :__service_init_called, false)
    Module.put_attribute(__CALLER__.module, :__service_provides_called, false)

    quote location: :keep do
      import unquote(__MODULE__), only: :macros

      @behaviour Service
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro inject(definition) do
    if Module.get_attribute(__CALLER__.module, :__service_init_called) do
      raise("cannot declare inject after init")
    end

    case Injector.register_inject(
           __CALLER__.module,
           :__service_inject_specs,
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

    if Module.get_attribute(__CALLER__.module, :__service_init_called) do
      raise("cannot declare input after call")
    end

    if Module.get_attribute(__CALLER__.module, :__service_provides_called) do
      raise("cannot declare output twice")
    end

    Module.put_attribute(__CALLER__.module, :__service_provides_called, true)
    Module.put_attribute(__CALLER__.module, :__service_provides_type, typedef)

    nil
  end

  defmacro __before_compile__(env) do
    [
      def_injects(env),
      def_provides(env)
    ]
  end

  defp def_injects(env) do
    specs = Injector.registered_injects(env.module, :__service_inject_specs)
    specs |> IO.inspect(label: "specs")

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
    provides_type = Module.get_attribute(env.module, :__service_provides_type)

    quote location: :keep do
      @impl Service
      @spec provides_spec :: ReturnSpec.t()
      def provides_spec do
        %ReturnSpec{type: unquote(provides_type)}
      end
    end
  end
end

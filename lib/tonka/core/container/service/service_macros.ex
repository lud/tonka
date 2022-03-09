defmodule Tonka.Core.Container.Service.ServiceMacros do
  alias Tonka.Core.Container
  alias Tonka.Core.Injector
  alias Tonka.Core.Container.InjectSpec
  alias Tonka.Core.Container.Service

  defmacro init_module do
    quote location: :keep do
      import unquote(__MODULE__), only: :macros

      @behaviour Service
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    [
      def_injects(env)
    ]
  end

  defp def_injects(env) do
    specs = Injector.registered_injects(env.module, :__service_inject_specs)

    quote location: :keep, generated: true do
      @__built_inject_specs for {key, defn} <- unquote(specs),
                                do: %InjectSpec{key: key, type: defn[:utype]}

      @impl Service

      # the arguments to the inject_specs function define for which function +
      # arity the inject is made for.  the arg_0n parameter tells for to
      # argument of this function the injects should be passed on. This value is
      # the zero-based argument index.

      @spec inject_specs(function :: atom, arity :: integer, arg_0n :: integer) :: [
              InjectSpec.t()
            ]

      def inject_specs(:init, 3, 0) do
        @__built_inject_specs
      end
    end
  end
end

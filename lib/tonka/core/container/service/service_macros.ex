defmodule Tonka.Core.Container.Service.ServiceMacros do
  alias Tonka.Core.Container
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
      # quote do
      #   if not (@tonka_call_called or Module.defines?(__MODULE__, {:call, 3}, :def)) do
      #     Tonka.Core.Operation.__raise_no_call(__MODULE__)
      #   end

      #   if not @tonka_output_called do
      #     Tonka.Core.Operation.__raise_no_output(__MODULE__)
      #   end
      # end,
      # def_inputs(env),
      # def_output(),
      # if(Module.get_attribute(env.module, :tonka_call_called), do: def_call(env))
    ]
  end
end

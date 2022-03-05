defmodule Comp do
  defmacro __using__(_) do
    Module.put_attribute(__CALLER__.module, :lol, 1)

    quote do
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro puts do
    Module.put_attribute(__CALLER__.module, :lol, 2)

    quote do
      def aaa, do: :ok
    end
  end

  defmacro __before_compile__(env) do
    Module.get_attribute(env.module, :lol)
    |> IO.inspect(label: "Module.get_attribute(env.module, :lol)")
  end
end

defmodule X do
  use Comp

  puts
end

defmodule Tonka.Core.Container.Type do
  @callback expand_type :: Tonka.Core.Container.typespec()

  @deprecated "remove all references to expand_type codebase-wide"
  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)
      # def expand_type, do: {:remote_type, __MODULE__, :t}
    end
  end
end

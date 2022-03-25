defmodule Tonka.GLogger do
  @moduledoc """
  A grid is an execution context for multiple actions.
  """

  defmacro __using__(_) do
    quote do
      require Logger
      alias Tonka.GLogger
    end
  end

  [:debug, :info, :warn, :error, :critical]
  |> Enum.each(fn level ->
    defmacro unquote(level)(message, meta \\ []) do
      level = unquote(level)

      quote do
        require Logger
        Logger.unquote(level)(unquote(message), unquote(meta))
        :ok
      end
    end
  end)
end

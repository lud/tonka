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

  def write_to_system_logs(enabled \\ true) do
    Process.put({__MODULE__, :system_logger_enabled}, enabled)
  end

  def system_logger_enabled? do
    Process.get({__MODULE__, :system_logger_enabled}, false)
  end

  [:debug, :info, :warn, :error, :critical]
  |> Enum.each(fn level ->
    defmacro unquote(level)(message, meta \\ []) do
      level = unquote(level)

      quote do
        require Logger

        if Tonka.GLogger.system_logger_enabled?() do
          Logger.unquote(level)(unquote(message), unquote(meta))
        end

        :ok
      end
    end
  end)
end

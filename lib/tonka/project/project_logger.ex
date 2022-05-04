defmodule Tonka.Project.ProjectLogger do
  @moduledoc """
  A grid is an execution context for multiple actions.
  """
  use TODO

  defmacro __using__(opts) do
    rename = Keyword.get(opts, :as, ProjectLogger)

    quote do
      require Logger

      alias Tonka.Project.ProjectLogger, as: unquote(rename)
    end
  end

  def enable_system_logs(enabled \\ true) do
    Process.put({__MODULE__, :system_logger_enabled}, enabled)
  end

  @todo "false by default"
  def system_logger_enabled? do
    Process.get({__MODULE__, :system_logger_enabled}, true)
  end

  [:debug, :info, :warn, :error, :critical]
  |> Enum.each(fn level ->
    defmacro unquote(level)(message, meta \\ []) do
      level = unquote(level)

      quote do
        require Logger

        if Tonka.Project.ProjectLogger.system_logger_enabled?() do
          Logger.unquote(level)(unquote(message), unquote(meta))
        end

        :ok
      end
    end
  end)
end

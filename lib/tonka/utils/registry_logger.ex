defmodule Tonka.Utils.RegistryLogger do
  use GenServer
  require Logger

  def start_link(gen_opts) do
    GenServer.start_link(__MODULE__, [], gen_opts)
  end

  def init([]) do
    {:ok, []}
  end

  def handle_info({:register, registry, name, pid, _}, state) do
    Logger.debug("#{inspect(registry)}: registered #{inspect(pid)} #{inspect(name)}")

    {:noreply, state}
  end

  def handle_info({:unregister, registry, name, pid}, state) do
    Logger.debug("#{inspect(registry)}: unregistered #{inspect(pid)} #{inspect(name)}")

    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end

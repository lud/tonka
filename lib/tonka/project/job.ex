defmodule Tonka.Project.Job do
  alias Tonka.Core.Grid
  alias Tonka.Project
  use GenServer, restart: :temporary, shutdown: 60_000

  def start_link(opts) do
    prk = Keyword.fetch!(opts, :prk)
    pubkey = Keyword.fetch!(opts, :publication)
    input = Keyword.fetch!(opts, :input)
    GenServer.start_link(__MODULE__, %{prk: prk, pub: pubkey, input: input}, [])
  end

  @impl GenServer
  def init(state) do
    {:ok, state, {:continue, :start}}
  end

  @impl GenServer
  def handle_continue(:start, %{prk: prk, pub: pubkey, input: input} = state) do
    with {:ok, pub} <- Project.fetch_publication(prk, pubkey),
         {:ok, container} <- Project.fetch_container(prk),
         :ok <- run_grid(pub, container, input) do
      {:stop, :normal, state}
    else
      {:error, reason} -> {:stop, reason, state}
    end
  end

  defp run_grid(pub, container, input) do
    grid = pub.grid

    case Grid.run(grid, container, input) do
      {:ok, :done, _grid} -> :ok
      {:error, detail, _grid} -> {:error, detail}
    end
  end
end

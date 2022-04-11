defmodule Tonka.Project.JobSup do
  use DynamicSupervisor

  require Logger

  def start_link(opts) do
    {gen_opts, opts} = Keyword.split(opts, [:name])
    prk = Keyword.fetch!(opts, :prk)
    DynamicSupervisor.start_link(__MODULE__, [prk: prk], gen_opts)
  end

  @impl true
  def init(prk: prk) do
    Logger.info("initializing job supervisor for #{prk}")
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

defmodule Tonka.Project.Job do
  use GenServer, restart: :temporary, shutdown: 60_000
  alias Tonka.Project
  alias Tonka.Core.Grid

  def start_link(opts) do
    prk = Keyword.fetch!(opts, :prk)
    pubkey = Keyword.fetch!(opts, :publication)
    input = Keyword.fetch!(opts, :input)
    GenServer.start_link(__MODULE__, %{prk: prk, pub: pubkey, input: input}, [])
  end

  @impl true
  def init(%{prk: prk, pub: pubkey, input: input} = state) do
    {:ok, state, {:continue, :start}}
  end

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

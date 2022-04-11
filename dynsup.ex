defmodule DS do
  use DynamicSupervisor

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg)
  end

  @impl true
  def init([]) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

defmodule Worker do
  use GenServer, shutdown: 5000

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  def init(_) do
    Process.flag(:trap_exit, true)
    {:ok, nil}
  end

  def terminate(reason, _) do
    IO.puts("terminating")
    Process.sleep(:infinity)
  end
end

{:ok, sup} = DS.start_link([])
# :brutal_kill = Worker.child_spec([]).shutdown
{:ok, worker} = DynamicSupervisor.start_child(sup, Worker)
Supervisor.stop(sup) |> IO.inspect(label: "Supervisor.stop(sup)")

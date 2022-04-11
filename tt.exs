Tonka.Demo.run()

# require Logger

# defmodule DS do
#   use DynamicSupervisor

#   def start_link(opts) do
#     {gen_opts, _opts} = Keyword.split(opts, [:name])
#     DynamicSupervisor.start_link(__MODULE__, [], gen_opts)
#   end

#   @impl true
#   def init([]) do
#     DynamicSupervisor.init(strategy: :one_for_one)
#   end
# end

# defmodule Sup do
#   use Supervisor

#   def start_link() do
#     Supervisor.start_link(__MODULE__, [])
#   end

#   @impl Supervisor
#   def init(_) do
#     children = [{DS, name: :ds}]

#     Supervisor.init(children, strategy: :one_for_all)
#   end
# end

# defmodule Worker do
#   use GenServer, shutdown: 3000

#   def start_link(opts) do
#     id = Keyword.fetch!(opts, :id)
#     parent = Keyword.fetch!(opts, :parent)
#     GenServer.start_link(__MODULE__, {id, parent})
#   end

#   def init({id, parent}) do
#     Process.flag(:trap_exit, true)
#     Logger.info("ds #{id} init")
#     {:ok, {id, parent}}
#   end

#   def terminate(reason, {id, parent}) do
#     send(parent, {id, :terminating})
#     Logger.info("ds #{id} terminating")
#     Process.sleep(:infinity)
#   end
# end

# Worker.child_spec([]) |> IO.inspect(label: "Worker.child_spec([])")

# {:ok, sup} = Sup.start_link()

# true = is_pid(Process.whereis(:ds))
# top = self()

# {:ok, alice} = DynamicSupervisor.start_child(:ds, {Worker, id: "alice", parent: top})

# ref = Process.monitor(alice)

# spawn_link(fn ->
#   Logger.info("stopping supervisor ...")
#   # never returns since child sleeping forever
#   Supervisor.stop(sup)
#   Logger.info("supervisor stopped")
# end)

# receive do
#   {"alice", :terminating} -> Logger.info("received :terminating from alice")
# after
#   1000 -> Logger.info("did not receive some news from alice")
# end

# # receive do
# #   {:DOWN, ^ref, :process, ^alice, reason} -> Logger.info("alice stopped with #{inspect(reason)}")
# # end

# try do
#   late_child_result = DynamicSupervisor.start_child(:ds, {Worker, id: "bob", parent: top})
#   late_child_result |> IO.inspect(label: "late_child_result")
# catch
#   :exit, {:shutdown, _} -> IO.puts("could not start child")
# end

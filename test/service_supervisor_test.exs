defmodule Tonka.ServiceSupervisorTest do
  use ExUnit.Case, async: true

  test "the service supervisor can be started" do
    # - Registry only supports atom names, so we have a node-wide process
    #   registry, or a node-wide service registry at least, for all projects.
    # - A service that wants to start a process must inject the service
    #   supervisor.
    # - Add a new function Service.start_child(service_supervisor, child_spec)
    #   to be called from build/2 like any other service
    # - This functions does not return {:ok, pid}, but {:ok, name}, where name
    #   will be a :via tuple. This should be the value returned from the build/2
    #   function. Use the process dictionary when calling that function to
    #   ensure that the name is what is actually returned. (The process
    #   dictionary is only used as a verification mechanism, to ensure that the
    #   name is actually reurned.)
    # - If the service supervisor (one in each project) dies, then
    IO.warn("todo define service supervision.")
  end
end

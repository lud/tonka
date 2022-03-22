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
    #   will be a :via tuple.
    # - The service can still return any value, like a struct. It may not even
    #   use the process at all.
    IO.warn("todo define service supervision.")
  end
end

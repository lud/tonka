defmodule Tonka.ProjectSchedulerTest do
  use ExUnit.Case, async: true
  alias Tonka.Project.Scheduler
  import Tonka.Utils

  test "parsing a scheduler spec" do
    raw =
      yaml!("""
      my_spec_1:
        timezone: Europe/Paris
        schedule: "0 8 * * *"

      "my_spec_2":
        schedule: "0 8 * * *"
      """)

    raw |> IO.inspect(label: "raw")
    spec = Scheduler.cast_specs(raw)
    spec |> IO.inspect(label: "spec")
  end

  test "The scheduler can be started with a name" do
    assert {:ok, pid} = Scheduler.start_link(name: :hello)
    assert Process.whereis(:hello) == pid
  end
end

defmodule Tonka.ProjectSchedulerTest do
  alias Crontab.CronExpression.Parser
  alias Tonka.Data.TimeInterval
  alias Tonka.Project.Scheduler
  import Tonka.Utils
  use ExUnit.Case, async: true

  test "parsing a scheduler spec" do
    raw =
      yaml!("""
      my_spec_1:
        timezone: Europe/Paris
        schedule: "0 8 * * *"
        run:
          grid: "grid_1"
          input: none

      "my_spec_2":
        schedule: "0 8 * * *"
        run:
          grid: "grid_2"
          input: none
      """)

    assert {:ok, _spec} = Scheduler.cast_specs(raw)
  end

  test "The scheduler can be started with a name" do
    assert {:ok, pid} = Scheduler.start_link(name: :hello, specs: [], prk: "test")
    assert Process.whereis(:hello) == pid
  end

  test "the scheduler will execute the specs" do
    raw =
      yaml!("""
      my_spec_1:
        timezone: Europe/Paris
        schedule: "0 8 * * *"
        max_attempts: 2
        run:
          grid: "grid_1"
          input: none

      my_spec_2:
        timezone: Europe/Paris
        schedule: "0 8 * * *"
        max_attempts: 2
        run:
          grid: "grid_1"
          input: none
      """)

    # Test with two specs, both of them must be called in time
    assert {:ok, [spec1, spec2]} = Scheduler.cast_specs(raw)
    test = self()

    # modify specs for test
    # - Replace the cron expression with a every-second expression
    # - Replace the command with a fun, which is accepted. The fun will be
    #   executed in the scheduler process, this is designed only for tests, so
    #   we will leverage the process dictionary

    # the function will fake an attempt to run and then run correctly

    runner = fn tag ->
      fn ->
        attempted = {:test, tag}

        case Process.get(attempted, false) do
          true ->
            send(test, {:ok, tag})
            :ok

          false ->
            send(test, {:attempt, tag})
            Process.put(attempted, true)
            {:error, :failed_for_test}
        end
      end
    end

    spec1 =
      spec1
      |> Map.put(:run, runner.(:foo))
      |> Map.put(:schedule, Parser.parse!("* * * * * *", true))

    spec2 =
      spec2
      |> Map.put(:run, runner.(:bar))
      |> Map.put(:schedule, Parser.parse!("* * * * * *", true))

    assert {:ok, pid} = Scheduler.start_link(specs: [spec1, spec2], prk: "test")

    # as it is an async test, we let a loose time for the server to start
    assert_receive {:attempt, :foo}, 2000
    assert_receive {:attempt, :bar}, 500
    assert_receive {:ok, :foo}, 500
    assert_receive {:ok, :bar}, 500

    GenServer.stop(pid)
  end

  test "formatting a time interval" do
    t = "2d1h12s"
    ms = TimeInterval.to_ms!(t)
    assert t == TimeInterval.to_string(ms)
  end
end

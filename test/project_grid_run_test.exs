defmodule Tonka.ProjectGridRunTest do
  alias Tonka.Core.Action
  alias Tonka.Core.Container
  alias Tonka.Core.Grid
  alias Tonka.Core.Grid.CastError
  alias Tonka.Core.Grid.InvalidInputTypeError
  alias Tonka.Core.Grid.NoInputCasterError
  alias Tonka.Core.Grid.UndefinedOriginActionError
  alias Tonka.Core.Grid.UnmappedInputError
  use ExUnit.Case, async: true

  @credentials """
  {

  }
  """

  @layout """
  scheduler:
    dev_issues:
      schedule: "* * * * * *"
      timezone: "Europe/Paris"
      run:
        grid: "grid_2"
        input: none

  publications:
    test_cli:
      grid:
        gen_booklet:
          use: core.render.booklet_wrapper
          params:
            title: Test Grid
          inputs:
            above:
              origin: static
              static:
                - header: My Wrapper
                - mrkdwn: |-
                    This is top
            below:
              origin: static
              static:
                - mrkdwn: "Thank you for reading"
            content:
              origin: grid_input

        print_booklet:
          use: core.render.booklet_cli
          inputs:
            booklet:
              origin: action
              action: gen_booklet



  """

  setup do
    {:ok, dir} = Briefly.create(directory: true)
    File.write!(Path.join(dir, "project.yaml"), @layout)
    File.write!(Path.join(dir, "credentials.json"), @credentials)
    %{dir: dir}
  end

  test "a project can be started", %{dir: dir} do
    prk = "gridtest"
    {:ok, pid} = Tonka.Project.start_project(prk: prk, dir: dir)

    assert :ok = Tonka.Project.run_publication(prk, "test_cli", "my input")
  end
end

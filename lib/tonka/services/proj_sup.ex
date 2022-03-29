defmodule Tonka.Project.ProjectSupervisor do
  use Supervisor

  @moduledoc """
  The supervisor that manages all loaded projects for this node.
  """

  # ---------------------------------------------------------------------------
  #  Supervisor
  # ---------------------------------------------------------------------------

  def start_link([]) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl Supervisor
  def init(_init_arg) do
    children = Enum.map(list_projects, &project_child_spec/1)

    Supervisor.init(children, strategy: :one_for_one)
  end

  def list_projects do
    ["dev"]
  end

  def project_child_spec(prk) do
    args = [prk: prk]

    args
    |> Tonka.Project.child_spec()
    |> Supervisor.child_spec(id: prk)
  end
end

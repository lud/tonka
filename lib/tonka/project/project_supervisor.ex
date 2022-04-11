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
    children = Enum.map(list_projects(), &project_child_spec/1)

    Supervisor.init(children, strategy: :one_for_one)
  end

  def list_projects do
    case Application.fetch_env!(:tonka, :start_projects) do
      :all -> list_projects_from_disk()
      :none -> []
      list -> list
    end
  end

  @projects_dir "var/projects"
  def list_projects_from_disk do
    Enum.filter(File.ls!(@projects_dir), fn prk ->
      dir = Path.join(@projects_dir, prk)
      yaml = Path.join(dir, "project.yaml")
      File.dir?(dir) and File.regular?(yaml)
    end)
  end

  def project_child_spec(prk) when is_binary(prk) do
    project_child_spec(prk: prk)
  end

  def project_child_spec(args) when is_list(args) do
    prk = Keyword.fetch!(args, :prk)

    args
    |> Tonka.Project.child_spec()
    |> Supervisor.child_spec(id: prk)
  end
end

defmodule Tonka.Project do
  use Supervisor
  alias Tonka.Project.ProjectRegistry
  alias Tonka.Project.Loader
  alias Tonka.Core.Container
  alias Tonka.Data.ProjectInfo

  require Logger

  @moduledoc """
  The supervisor that manages a single project's processes.
  """

  # ---------------------------------------------------------------------------
  #  Supervisor
  # ---------------------------------------------------------------------------

  def start_link(prk: prk) do
    name = name_for(prk, __MODULE__)
    Supervisor.start_link(__MODULE__, [prk: prk], name: name)
  end

  @impl Supervisor
  def init(prk: prk) do
    Logger.info("initializing project #{prk}")

    pinfo = project_info(prk)

    children = [
      {Tonka.Services.ServiceSupervisor, prk: prk, name: pinfo.service_sup_name},
      {Tonka.Project.Builder, pinfo: pinfo}

      # Job supervisor is last, as soon as there is a problem in the pipeline we
      # want it stopping and not accepting new children.
      # {Tonka.Project.JobSup, prk: prk, name: project.job_sup_name}
      # {Tonka.Project.Scheduler, prk: prk, specs: {:from_reg}}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  defp project_info(prk) do
    Tonka.Data.ProjectInfo.of(
      prk: prk,
      yaml_path: project_file(prk, "project.yaml"),
      storage_dir: project_file(prk, "storage"),
      credentials_path: project_file(prk, "credentials.json"),
      service_sup_name: name_for(prk, :services_sup),
      job_sup_name: name_for(prk, :jobs_sup),
      store_backend_name: name_for(prk, :store_backend)
    )
  end

  def project_dir(prk) do
    "var/projects/#{prk}"
  end

  defp project_file(prk, filename) do
    Path.join(project_dir(prk), filename)
  end

  defp name_for(prk, kind), do: ProjectRegistry.via(prk, kind)
end

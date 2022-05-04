defmodule Tonka.Project do
  alias Tonka.Core.Container
  alias Tonka.Data.ProjectInfo
  alias Tonka.Project.Loader
  alias Tonka.Project.ProjectRegistry
  require Logger
  use Supervisor

  @moduledoc """
  The supervisor that manages a single project's processes.
  """

  # ---------------------------------------------------------------------------
  #  Api
  # ---------------------------------------------------------------------------

  def start_project(prk_or_opts) when is_binary(prk_or_opts) when is_list(prk_or_opts) do
    cs = Tonka.Project.ProjectSupervisor.project_child_spec(prk_or_opts)
    Supervisor.start_child(Tonka.Project.ProjectSupervisor, cs)
  end

  def run_publication(prk, publication, input, timeout \\ :infinity) do
    spec = {Tonka.Project.Job, prk: prk, publication: publication, input: input}
    job_sup = job_sup_name(prk)

    case DynamicSupervisor.start_child(job_sup, spec) do
      {:ok, pid} -> await_job(pid, timeout)
      {:error, _} = err -> err
    end
  end

  defp await_job(pid, timeout) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, :normal} -> :ok
      {:DOWN, ^ref, :process, ^pid, reason} -> {:error, reason}
    after
      timeout ->
        Process.link(pid)
        Process.exit(pid, :kill)
    end
  end

  def fetch_publication(prk, key) do
    ProjectRegistry.fetch_value(prk, :publication, key)
  end

  def fetch_container(prk) do
    ProjectRegistry.fetch_value(prk, :container)
  end

  # ---------------------------------------------------------------------------
  #  Supervisor
  # ---------------------------------------------------------------------------

  def start_link(opts) do
    prk = Keyword.fetch!(opts, :prk)
    Logger.info("starting project #{prk}")
    dir = Keyword.get(opts, :dir, project_dir(prk))
    name = name_for(prk, __MODULE__)
    Supervisor.start_link(__MODULE__, [prk: prk, dir: dir], name: name)
  end

  @impl Supervisor
  def init(prk: prk, dir: dir) do
    Logger.info("initializing project #{prk} in #{dir}")

    pinfo = project_info(prk, dir)

    children = [
      {Tonka.Services.ServiceSupervisor, prk: prk, name: pinfo.service_sup_name},
      {Tonka.Project.Builder, pinfo: pinfo},

      # Job supervisor is last, as soon as there is a problem in the pipeline we
      # want it stopping and not accepting new children.
      {Tonka.Project.JobSup, prk: prk, name: pinfo.job_sup_name}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  def project_info(prk),
    do: project_info(prk, project_dir(prk))

  def project_info(prk, project_dir),
    do: project_info(prk, project_dir, storage_dir(prk))

  def project_info(prk, project_dir, storage_dir) do
    Tonka.Data.ProjectInfo.of(
      prk: prk,
      yaml_path: Path.join(project_dir, "project.yaml"),
      storage_dir: storage_dir,
      credentials_path: Path.join(project_dir, "credentials.json"),
      service_sup_name: name_for(prk, :services_sup),
      job_sup_name: job_sup_name(prk),
      store_backend_name: name_for(prk, :store_backend)
    )
  end

  def job_sup_name(prk),
    do: name_for(prk, :jobs_sup)

  def projects_dir,
    do: Application.fetch_env!(:tonka, :projects_dir)

  def project_dir(prk) when is_binary(prk),
    do: Path.join(projects_dir(), prk)

  def storage_dir,
    do: Application.fetch_env!(:tonka, :storage_dir)

  def storage_dir(prk) when is_binary(prk),
    do: Path.join(storage_dir(), prk)

  defp name_for(prk, kind),
    do: ProjectRegistry.via(prk, kind)
end

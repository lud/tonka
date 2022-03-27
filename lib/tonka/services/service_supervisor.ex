defmodule Tonka.Services.ServiceSupervisor do
  alias Tonka.Project.ProjectRegistry
  use Supervisor
  use Tonka.Core.Service

  @moduledoc """
  A generic one_for_one supervisor with an API dedicated to start process-based
  services within a project.
  """

  @impl Service
  def cast_params(term) do
    {:ok, term}
  end

  @impl Service
  def configure(config) do
    config
    |> use_service(:info, Tonka.Data.ProjectInfo)
  end

  def start_link(opts) do
    prk = Keyword.fetch!(opts, :prk)
    name = ProjectRegistry.via(prk, __MODULE__)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl Supervisor
  def init(_init_arg) do
    children = []

    Supervisor.init(children, strategy: :one_for_one)
  end
end

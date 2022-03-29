defmodule Tonka.Services.ServiceSupervisor do
  use Supervisor

  @moduledoc """
  A generic one_for_one supervisor with an API dedicated to start process-based
  services within a project.
  """

  # ---------------------------------------------------------------------------
  #  Supervisor
  # ---------------------------------------------------------------------------

  def start_link(prk: prk) do
    name = Tonka.Project.ProjectRegistry.via(prk, __MODULE__)
    Supervisor.start_link(__MODULE__, [], name: name)
  end

  @impl Supervisor
  def init(_init_arg) do
    children = []

    Supervisor.init(children, strategy: :one_for_one)
  end
end

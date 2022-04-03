defmodule Tonka.Project do
  use Supervisor

  @moduledoc """
  The supervisor that manages a single project's processes.
  """

  # ---------------------------------------------------------------------------
  #  Supervisor
  # ---------------------------------------------------------------------------

  def start_link(prk: prk) do
    name = Tonka.Project.ProjectRegistry.via(prk, __MODULE__)
    Supervisor.start_link(__MODULE__, [prk: prk], name: name)
  end

  @impl Supervisor
  def init(prk: prk) do
    children = [
      {Tonka.Project.DepsSup, prk: prk}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule Tonka.Project.DepsSup do
  use Supervisor

  @moduledoc """
  The supervisor that manages a single project's processes.
  """

  # ---------------------------------------------------------------------------
  #  Supervisor
  # ---------------------------------------------------------------------------

  def start_link(prk: prk) do
    Supervisor.start_link(__MODULE__, prk: prk)
  end

  @impl Supervisor
  def init(prk: prk) do
    children = [
      {Tonka.Services.ServiceSupervisor, prk: prk},
      {Tonka.Project.ProjectLoader, prk: prk}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

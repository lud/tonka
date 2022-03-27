defmodule Tonka.Services.ServiceSupervisor do
  @moduledoc """
  A generic one_for_one supervisor with an API dedicated to start process-based
  services within a project.
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = []

    Supervisor.init(children, strategy: :one_for_one)
  end
end

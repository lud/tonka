defmodule Tonka.Project.JobSup do
  # Automatically defines child_spec/1
  use DynamicSupervisor

  def start_link(prk: prk) do
    name = Tonka.Project.ProjectRegistry.via(prk, __MODULE__)
    DynamicSupervisor.start_link(__MODULE__, [], name: name)
  end

  @impl true
  def init([]) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

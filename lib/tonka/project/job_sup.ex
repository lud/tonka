defmodule Tonka.Project.JobSup do
  use DynamicSupervisor

  def start_link(opts) do
    {gen_opts, _opts} = Keyword.split(opts, [:name])
    DynamicSupervisor.start_link(__MODULE__, [], gen_opts)
  end

  @impl true
  def init([]) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

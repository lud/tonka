defmodule Tonka.Project.JobSup do
  use DynamicSupervisor

  require Logger

  def start_link(opts) do
    {gen_opts, opts} = Keyword.split(opts, [:name])
    prk = Keyword.fetch!(opts, :prk)
    DynamicSupervisor.start_link(__MODULE__, [prk: prk], gen_opts)
  end

  @impl true
  def init(prk: prk) do
    Logger.info("initializing job supervisor for #{prk}")
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

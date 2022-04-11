defmodule Tonka.Services.ServiceSupervisor do
  use Supervisor
  require Logger

  @moduledoc """
  A generic one_for_one supervisor with an API dedicated to start process-based
  services within a project.
  """

  # ---------------------------------------------------------------------------
  #  Supervisor
  # ---------------------------------------------------------------------------

  def start_link(opts) do
    {gen_opts, opts} = Keyword.split(opts, [:name])
    Supervisor.start_link(__MODULE__, opts, gen_opts)
  end

  @impl Supervisor
  def init(prk: prk) do
    Logger.info("initializing service supervisor #{prk} as #{inspect(self())}")
    children = []

    Supervisor.init(children, strategy: :one_for_one)
  end
end

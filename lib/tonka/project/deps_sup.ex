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
      {Tonka.Services.ServiceSupervisor, prk: prk}

      # tada """
      # 1. start le service sup
      # 2. start le scheduler qui démarre avec une liste vide
      # 3. start le loader qui peut register le container, les grids,
      #    en envoyer au scheduler un reset() avec le schedule de la config
      # 4. Idem pour tout autre service dépendent de la config : on le start
      #    d'abord et le loader lui envoie ses infos. si besoin au lieu d'un
      #    call() le service attend les infos dans un receive dans le :continue
      #    du init()

      # """

      # Todo
      # - load the project YAML
      # - create the container + freeze, register as value
      # - create each grid, register as value
      # - create each grid, register as value
      # {Tonka.Project.ProjectLoader, prk: prk}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end

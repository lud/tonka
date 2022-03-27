defmodule Tonka.Project.ProjectRegistry do
  @registry __MODULE__

  @spec child_spec([]) :: Supervisor.child_spec()
  def child_spec([]) do
    Registry.child_spec(
      name: __MODULE__,
      keys: :unique,
      listeners: [Tonka.Utils.RegistryLogger]
    )
  end

  @type name :: {unquote(@registry), {binary, atom} | {binary, atom, term}}

  @spec via(prk :: binary, kind :: atom, id :: term) :: {:via, Registry, name()}
  def via(prk, kind \\ nil, id \\ nil)

  def via(prk, kind, id),
    do: {:via, Registry, {@registry, process_key(prk, kind, id)}}

  def lookup(prk, kind, id \\ nil) do
    Registry.lookup(@registry, process_key(prk, kind, id))
  end

  def whereis(prk, kind, id \\ nil) do
    Registry.whereis_name({@registry, process_key(prk, kind, id)})
  end

  defp process_key(prk, kind, nil), do: {prk, :server, kind}
  defp process_key(prk, kind, id), do: {prk, :server, kind, id}

  def project_started?(prk) do
    case lookup(prk, :project) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  def started_prks do
    Registry.select(@registry, [{{{:"$1", :project}, :_, :_}, [], [:"$1"]}])
  end
end

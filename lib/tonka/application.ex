defmodule Tonka.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children = tz_stack() ++ db_stack() ++ project_stack() ++ http_stack()

    opts = [strategy: :one_for_one, name: Tonka.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp project_stack do
    [
      {Tonka.Utils.RegistryLogger, name: Tonka.Utils.RegistryLogger},
      Tonka.Project.ProjectRegistry,
      Tonka.Project.ProjectSupervisor
    ]
  end

  defp tz_stack do
    if Application.get_env(:tonka, :refresh_tz, false) do
      [{Tz.UpdatePeriodically, []}]
    else
      []
    end
  end

  defp db_stack do
    [Tonka.Repo]
  end

  defp http_stack do
    [
      TonkaWeb.Telemetry,
      {Phoenix.PubSub, name: Tonka.PubSub},
      TonkaWeb.Endpoint
    ]
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    TonkaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

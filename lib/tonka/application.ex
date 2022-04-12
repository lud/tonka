defmodule Tonka.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @mix_env Mix.env()

  @impl Application
  def start(_type, _args) do
    Tonka.Extension.load_extensions()

    children =
      :lists.flatten([
        tz_stack(@mix_env),
        db_stack(@mix_env),
        http_stack(@mix_env),
        project_stack(@mix_env)
      ])

    opts = [strategy: :one_for_one, name: Tonka.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp project_stack(_) do
    [
      {Tonka.Utils.RegistryLogger, name: Tonka.Utils.RegistryLogger},
      Tonka.Project.ProjectRegistry,
      Tonka.Project.ProjectSupervisor
    ]
  end

  defp tz_stack(_) do
    if Application.get_env(:tonka, :refresh_tz, false) do
      [{Tz.UpdatePeriodically, []}]
    else
      []
    end
  end

  defp db_stack(:test), do: [Tonka.Repo]
  defp db_stack(_), do: []

  defp http_stack(:test) do
    [
      TonkaWeb.Telemetry,
      {Phoenix.PubSub, name: Tonka.PubSub},
      TonkaWeb.Endpoint
    ]
  end

  defp http_stack(_), do: []

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    TonkaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

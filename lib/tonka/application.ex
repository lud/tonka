defmodule Tonka.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Tonka.Repo,
      # Start the shared registry for projects and services
      {Tonka.Utils.RegistryLogger, name: Tonka.Utils.RegistryLogger},
      Tonka.Project.ProjectRegistry,
      # Start all configured Projects
      Tonka.Project.ProjectSupervisor,
      # Start the Telemetry supervisor
      TonkaWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Tonka.PubSub},
      # Start the Endpoint (http/https)
      TonkaWeb.Endpoint
      # Start a worker by calling: Tonka.Worker.start_link(arg)
      # {Tonka.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Tonka.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    TonkaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

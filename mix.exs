defmodule Tonka.MixProject do
  use Mix.Project

  def project do
    [
      app: :tonka,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      modkit: modkit(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Tonka.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # defp elixirc_paths(_), do: ["lib", "test/support"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix stack
      {:phoenix, "~> 1.6.6"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.6"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_live_dashboard, "~> 0.6"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.18"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},

      # App

      {:ark, "~> 0.6.1", runtime: false},
      # {:type_check, "~> 0.10.0"},

      # dev, test, tools
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.28.0", only: [:dev, :test], runtime: false},
      {:mix_version, "~> 1.3", runtime: false},
      {:modkit, path: "~/src/modkit"},
      {:todo, "~> 1.6", runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end

  defp modkit do
    [
      mount: [
        {Tonka.Test, "test/support"},
        {TonkaWeb.Test, "test/support"},
        {Tonka, "lib/tonka"},
        {TonkaWeb, {:phoenix, "lib/tonka_web"}}
      ]
    ]
  end
end

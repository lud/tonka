defmodule Tonka.MixProject do
  use Mix.Project

  def project do
    [
      app: :tonka,
      version: "0.1.0",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:gettext] ++ Mix.compilers(),
      consolidate_protocols: Mix.env() != :test,
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      modkit: modkit(),
      deps: deps(),
      docs: docs()
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
      # App

      {:ark, "~> 0.7.6"},
      {:hugs, path: "~/src/hugs"},
      # {:hugs, "~> 0.1.13"},
      {:yaml_elixir, "~> 2.5"},
      {:bbmustache, "~> 1.12"},
      {:nimble_options, "~> 0.4.0"},
      {:tesla, "~> 1.4"},
      {:hackney, "~> 1.17"},
      {:oban, "~> 2.11"},
      {:cubdb, "~> 1.1"},
      {:slack, "~> 0.23"},
      {:ymlr, "~> 2.0", only: :dev},
      {:time_queue, "~> 1.0"},
      {:tz, "~> 0.20.1"},
      {:castore, "~> 0.1.11"},
      {:mint, "~> 1.3"},
      {:crontab, "~> 1.1"},

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

      # dev, test, tools
      {:briefly, "~> 0.3"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.28.0", only: [:dev, :test], runtime: false},
      {:mix_version, "~> 1.3", runtime: false},
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

  defp docs do
    [
      source_ref: git_branch(),
      output: "doc/",
      formatters: ["html"],
      # assets: "priv/docs-assets",
      # javascript_config_path: "assets/docs.js",
      nest_modules_by_prefix: [
        Tonka.Core,
        Tonka.Actions.Queries,
        Tonka.Actions.Render,
        Tonka.Actions.Publish,
        Tonka.Actions,
        Tonka.Services,
        Tonka.Data,
        Tonka.Renderer,
        Tonka.T,
        Tonka.Utils,
        Tonka.Ext.Gitlab,
        Tonka.Ext.Slack,
        Tonka.Ext,
        TonkaWeb
      ],
      before_closing_body_tag: fn :html ->
        nil
        # File.read!("priv/docs-bottom.html")
      end
    ]
  end

  defp git_branch do
    System.get_env("CI_COMMIT_REF_NAME", "develop")
  end
end

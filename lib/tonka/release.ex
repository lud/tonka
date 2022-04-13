defmodule Tonka.Release do
  @moduledoc """
  Used for executing tasks when run in production without Mix installed.
  """
  @app :tonka

  def load_env_files(files) do
    files
    |> map_envs()
    |> Dotenvy.source!()
  end

  defp map_envs(files) do
    Enum.flat_map(files, fn
      :system ->
        [System.get_env()]

      path when is_binary(path) ->
        case File.regular?(path) do
          true ->
            IO.puts("using env file: #{path}")
            [path]

          false ->
            []
        end
    end)
  end

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end

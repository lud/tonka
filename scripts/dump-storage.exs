defmodule DumpStorage do
  def run do
    loadenv()

    repos = list_repos(root_dir())

    Enum.each(repos, &dump_repo/1)
  end

  defp dump_repo(dir) do
    {:ok, cub} = CubDB.start_link(dir)

    IO.puts([?\n, String.pad_trailing("== STORAGE #{dir} =", 30, "="), ?\n])

    case CubDB.select(cub) do
      {:ok, []} ->
        IO.puts([IO.ANSI.yellow(), "The storage is empty", IO.ANSI.reset()])

      {:ok, all} ->
        for {k, v} <- all do
          IO.puts("""
          ----
          #{[IO.ANSI.cyan(), inspect(k, pretty: true), IO.ANSI.reset()]}
          #{inspect(v, pretty: true)}
          """)
        end
    end
  end

  defp list_repos(root) do
    root
    |> File.ls!()
    |> Enum.map(&Path.join(root, &1))
    |> Enum.filter(&File.dir?/1)
  end

  defp loadenv do
    Mix.Task.run("loadpaths")
    Mix.Task.run("app.config")
  end

  defp root_dir, do: Tonka.Project.storage_dir()
end

DumpStorage.run()

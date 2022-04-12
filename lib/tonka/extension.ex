defmodule Tonka.Extension do
  @moduledoc """
  Defines the behaviour for extensions providing actions and services
  """
  require Logger

  @callback services :: %{binary => module}
  @callback actions :: %{binary => module}

  def list_extensions do
    [Tonka.Ext.BuiltIn, Tonka.Ext.Slack, Tonka.Ext.Gitlab]
  end

  def build_service_index do
    # Merge in order of the list_extensions config value so it is possible to
    # override previous definitions with new modules
    Enum.reduce(list_extensions(), %{}, fn mod, acc -> Map.merge(acc, mod.services()) end)
  end

  def build_action_index do
    # Merge in order of the list_extensions config value so it is possible to
    # override previous definitions with new modules
    Enum.reduce(list_extensions(), %{}, fn mod, acc -> Map.merge(acc, mod.actions()) end)
  end

  def load_extensions do
    ext_dir = Application.fetch_env!(:tonka, :extensions_dir)
    Logger.info("loading extensions from #{ext_dir}")
    paths = Path.wildcard("#{ext_dir}/*.ez")

    ext_mods =
      paths
      |> Stream.map(&load_extension/1)
      |> Stream.filter(fn
        {:ok, ext_mod} ->
          Logger.info("extension #{inspect(ext_mod)} loaded")
          true

        {:error, reason} ->
          Logger.error("could not load extension: " <> Ark.Error.to_string(reason))
          false
      end)
      |> Enum.map(&Ark.Ok.uok!/1)

    ext_mods |> IO.inspect(label: "ext_mods")
  end

  @re_ez ~r"\/(([a-zA-Z0-9_]+)-[0-9.]+)\.ez"

  def load_extension(path) do
    Logger.info("loading extension from #{path}")

    with {:ok, zipdir, bin_name} <- parse_ext_path(path),
         {:ok, ebin_dir} <- make_code_path(path, zipdir),
         app = String.to_atom(bin_name),
         :ok <- append_code_path(ebin_dir),
         :ok <- load_app_modules(path, zipdir, app),
         :ok <- load_app(app),
         {:ok, ext_mod} <- get_ext_mod(app),
         :ok <- start_app(app) do
      {:ok, ext_mod}
    else
      {:error, _} = err -> err
    end
  end

  defp load_app(app) do
    Logger.info("loading application #{app}")
    Application.ensure_loaded(app)
  end

  defp start_app(app) do
    Logger.info("starting application #{app}")
    Application.ensure_started(app)
  end

  defp get_ext_mod(app) do
    with {:ok, appinfo} <- :application.get_all_key(app),
         {:ok, env} <- Keyword.fetch(appinfo, :env),
         {:ok, mod} when is_atom(mod) <- Keyword.fetch(env, :tonka_extension) do
      {:ok, mod}
    else
      :undefined -> {:error, "application #{app} was not correctly loaded"}
      :error -> {:error, "could not find :tonka_extension module in app #{app} env"}
      _ -> {:error, "could not read extension module from app #{app}"}
    end
  end

  defp append_code_path(ebin_dir) do
    Logger.debug("adding #{ebin_dir} to code path")

    case :code.add_patha(ebin_dir) do
      true -> :ok
      {:error, _} = err -> err
    end
  end

  defp load_app_modules(ez_path, zipdir, app) do
    appfile = Path.join([zipdir, "ebin", "#{app}.app"]) |> String.to_charlist()

    unzipped = :zip.extract(String.to_charlist(ez_path), [{:file_list, [appfile]}, :memory])

    with {:ok, [{^appfile, content}]} <- unzipped,
         {:ok, appspec} <- parse_app_file(content),
         {:ok, modules} <- fetch_app_modules(appspec, app),
         :ok <- ensure_loaded_all(modules) do
      :ok
    end
  end

  defp ensure_loaded_all(modules) do
    :code.ensure_modules_loaded(modules)
  end

  defp fetch_app_modules(appspec, app) do
    case appspec do
      {:application, ^app, spec} ->
        case Keyword.fetch(spec, :modules) do
          {:ok, _} = fine -> fine
          :error -> {:error, "missing modules from app file for #{app}"}
        end

      _ ->
        {:error, "invalid app file for #{app}"}
    end
  end

  defp parse_app_file(content) do
    {:ok, ts, _} = :erl_scan.string(String.to_charlist(content))
    {:ok, _term} = :erl_parse.parse_term(ts)
  catch
    _, _ -> {:error, "invalid app file"}
  end

  defp make_code_path(path, zipdir) do
    ebin_dir = String.to_charlist(Path.join([path, zipdir, "ebin"]))
    {:ok, ebin_dir}
  end

  defp parse_ext_path(path) do
    case Regex.run(@re_ez, path, capture: :all_but_first) do
      [zipdir, bin_name] -> {:ok, zipdir, bin_name}
      _ -> {:error, "invalid archive filename: #{path}"}
    end
  end

  def ensure_loaded(ext) do
    ext.services |> Map.values() |> Enum.each(&Code.ensure_loaded!/1)
    ext.actions |> Map.values() |> Enum.each(&Code.ensure_loaded!/1)
  end
end

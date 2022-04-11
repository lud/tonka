defmodule Tonka.Project.Builder do
  @moduledoc """
  Write a little description of the module …
  """
  alias Tonka.Project.Loader
  alias Tonka.Core.Container
  alias Tonka.Data.ProjectInfo
  alias Tonka.Project
  use GenServer
  require Logger

  @gen_opts ~w(name timeout debug spawn_opt hibernate_after)a

  def start_link(opts) do
    {gen_opts, opts} = Keyword.split(opts, @gen_opts)
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @impl GenServer
  def init(pinfo: pinfo) do
    Logger.info("building project #{pinfo.prk}")

    case build_project(pinfo) do
      :ok -> {:ok, nil, :hibernate}
      {:error, reason} -> {:stop, reason}
    end
  end

  def build_project(pinfo) do
    Logger.info("building project #{pinfo.prk}")

    with {:ok, yaml} <- File.read(pinfo.yaml_path),
         {:ok, raw_layout} <- load_yaml(yaml),
         {:ok, layout} <- read_layout(raw_layout),
         :ok <- build_container(pinfo, layout) do
      :ok
    end
  end

  defp load_yaml(yaml) do
    case Tonka.Utils.yaml(yaml) do
      {:ok, map} when is_map(map) -> {:ok, map}
      {:error, _} = err -> err
    end
  end

  defp read_layout(raw) do
    {:ok, _} = Loader.get_definitions(raw)
  end

  defp build_container(%{prk: prk} = pinfo, layout) do
    true = is_pid(GenServer.whereis(pinfo.service_sup_name))

    File.mkdir_p!(pinfo.storage_dir)

    container =
      Container.new()
      |> Container.bind_impl(ProjectInfo, ProjectInfo.new(pinfo))
      |> Container.bind_impl(Tonka.Services.ServiceSupervisor, pinfo.service_sup_name)
      |> Container.bind(
        Tonka.Services.ProjectStore.Backend,
        Tonka.Services.ProjectStore.CubDBBackend
      )
      |> Container.bind(Tonka.Services.ProjectStore)
      |> Container.bind(Tonka.Services.Credentials, &build_credentials(&1, pinfo))

    container =
      Enum.reduce(layout.services, container, fn {_name, sdef}, c ->
        utype = service_type(sdef.module)
        Container.bind(c, utype, sdef.module, params: sdef.params)
      end)

    with {:ok, container} <- Container.prebuild_all(container) do
      Tonka.Project.ProjectRegistry.register_value(prk, :container, Container.freeze(container))
      :ok
    end
  end

  defp service_type(module) do
    case function_exported?(module, :service_type, 0) do
      true ->
        module.service_type()

      false ->
        Logger.error("""
        function not exported from #{inspect(module)}

            @impl Tonka.Core.Service
            def service_type, do: __MODULE__
        """)

        Logger.flush()

        exit("service #{module} has no type")
    end
  end

  defp build_credentials(container, pinfo) do
    store = Tonka.Services.Credentials.JsonFileCredentials.from_path!(pinfo.credentials_path)
    {:ok, store, container}
  end
end

# Process.exit(GenServer.whereis(Tonka.Project.project_name("dev")), :kill)

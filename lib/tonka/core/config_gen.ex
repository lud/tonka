defmodule Tonka.Core.ConfigGen do
  alias Tonka.Core.Container
  alias Tonka.Core.Service
  alias Tonka.Core.Grid
  alias Tonka.Core.Action

  def generate_config(container, grids) do
    services = generate_services(container)
    %{services: services, publications: generate_grids(grids)}
  end

  defp generate_services(%Container{} = container) do
    Enum.flat_map(container.services, fn {_utype, %Service{} = service} ->
      if is_config_service(service.builder) do
        name = random_name(:service)

        [{name, gen_service(service)}]
      else
        []
      end
    end)
    |> Enum.into(%{})
  end

  defp random_name(type), do: "my_#{type}-#{next_int()}"

  defp next_int do
    Process.info(self(), :reductions) |> elem(1)
  end

  defp is_config_service(nil), do: false
  defp is_config_service(builder) when not is_atom(builder), do: false
  defp is_config_service(Tonka.Services.CleanupStore), do: false
  defp is_config_service(Tonka.Services.ProjectStore), do: false
  defp is_config_service(Tonka.Services.ProjectStore.CubDBBackend), do: false
  defp is_config_service(_), do: true

  defp gen_service(%Service{} = service) do
    map = %{module: unmap_module(service.builder)}

    put_params(map, service.params)
  end

  defp put_params(map, params), do: put_noempty(map, :params, params)
  defp put_inputs(map, inputs), do: put_noempty(map, :inputs, inputs)

  defp put_noempty(map, key, sub) when map_size(sub) > 0 do
    Map.put(map, key, sub)
  end

  defp put_noempty(map, _key, sub) when is_map(sub) do
    map
  end

  defp generate_grids(grids) do
    Enum.into(grids, %{}, fn grid -> {random_name(:grid), gen_grid(grid)} end)
  end

  defp gen_grid(%Grid{} = grid) do
    grid.actions
    |> Enum.filter(fn {_, action} -> public_action?(action.module) end)
    |> Enum.into(%{}, fn {name, action} -> {name, gen_action(action)} end)
  end

  defp public_action?(Tonka.Actions.Render.BookletCliRenderer), do: false
  defp public_action?(_), do: true

  defp gen_action(%Action{} = act) do
    {:ok, act} = Action.preconfigure(act)

    map = %{module: unmap_module(act.module)}

    map
    |> put_params(act.params)
    |> put_inputs(act.input_mapping)
  end

  defp unmap_module(Tonka.Ext.Slack.Services.SlackAPI),
    do: "ext.slack.api"

  defp unmap_module(Tonka.Ext.Gitlab.Services.Issues),
    do: "ext.gitlab.issues"

  defp unmap_module(Tonka.Services.IssuesStore),
    do: "core.issues_store"

  defp unmap_module(Tonka.Actions.Queries.QueriesGroupsMQLCompiler),
    do: "core.query.mql.compile_groups"

  defp unmap_module(Tonka.Actions.Render.IssuesGroupsBookletRenderer),
    do: "core.render.booklet.issues_groups"

  defp unmap_module(Tonka.Actions.Queries.IssuesGroupsReader),
    do: "core.query.issues_groups_reader"

  defp unmap_module(Tonka.Actions.Render.BookletWrapper),
    do: "core.render.booklet_wrapper"

  defp unmap_module(Tonka.Ext.Slack.Actions.SlackPublisher),
    do: "ext.slack.slack_publisher"

  defp unmap_module(other) do
    IO.puts(
      yellow("""
        defp unmap_module(#{inspect(other)}), do: "_____________"
      """)
    )
  end

  defp yellow(c) do
    [IO.ANSI.yellow(), c, IO.ANSI.reset()]
  end
end

defmodule Tonka.IssuesStoreTest do
  use ExUnit.Case, async: true

  alias Tonka.Core.Query.MQL
  alias Tonka.Core.Container
  alias Tonka.Core.Service
  alias Tonka.Services.IssuesStore
  alias Tonka.Services.IssuesSource

  defmodule TestIssuesSources do
    @derive IssuesSource
    defstruct [:funs]

    require(Tonka.Test.Stubber).stub_funs(IssuesSource)

    def impl(funs) when is_map(funs) do
      %__MODULE__{funs: funs}
    end
  end

  test "assert the stubber" do
    impls = %{mql_query: fn _, q -> {:got, q} end}

    assert {:got, :some_query} =
             Tonka.Services.IssuesSource.mql_query(
               TestIssuesSources.impl(impls),
               :some_query
             )
  end

  test "the issues store is a service" do
    assert Tonka.Core.Reflection.implements_behaviour?(IssuesStore, Service)
  end

  test "the issues store requires an issues source" do
    assert %Service.ServiceConfig{} = config = IssuesStore.configure(Service.base_config())
    assert Enum.any?(config.injects, fn {_, %{type: t}} -> t == IssuesSource end)
  end

  test "the issues store can be built as a service" do
    # For now the issues store is not process-based. Once it will be, it will
    # try to fetch the issues on startup. In that case we will need to mock all
    # the functions from here.
    service = Service.new(IssuesStore)
    assert {:ok, %{impl: %IssuesStore{}}, _} = Service.build(service, container(%{}))
  end

  defp container(funs) do
    Container.new() |> Container.bind_impl(IssuesSource, TestIssuesSources.impl(funs))
  end

  defp build_store(funs) do
    service = Service.new(IssuesStore)
    assert {:ok, %{impl: %IssuesStore{} = store}, _} = Service.build(service, container(%{}))
    store
  end

  test "the issues store can query groups of issues" do
    store = build_store(%{})

    groups =
      """
      - title: Group with limit 1
        query:
          labels: 'todo'
        limit: 1
      - title: Group with no limit
        query:
          labels: 'doing'
      """
      |> YamlElixir.read_from_string!()
      |> Tonka.T.MQLGroups.cast_input()
      |> Ark.Ok.uok!()
      |> Enum.map(fn group ->
        query =
          MQL.compile!(group.query,
            as_atoms: Tonka.Util.TypeUtils.struct_binary_keys(Tonka.Data.Issue)
          )

        Map.put(group, :query, query)
      end)
      |> IO.inspect(label: "compiled")

    store |> IO.inspect(label: "store")

    assert {:ok, [_, _]} = IssuesStore.query_groups(store, groups)
  end
end

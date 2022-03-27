defmodule Tonka.IssuesStoreTest do
  alias Tonka.Core.Container
  alias Tonka.Core.Query.MQL
  alias Tonka.Core.Service
  alias Tonka.Data.Issue
  alias Tonka.Services.IssuesSource
  alias Tonka.Services.IssuesStore
  use ExUnit.Case, async: true

  defmodule TestIssuesSources do
    @derive IssuesSource
    defstruct [:funs]

    require(Tonka.Test.Stubber).stub_funs(IssuesSource)

    def impl(funs) when is_map(funs) do
      %__MODULE__{funs: funs}
    end
  end

  test "assert the stubber" do
    impls = %{fetch_all_issues: fn _ -> :stubbed! end}

    assert :stubbed! = Tonka.Services.IssuesSource.fetch_all_issues(TestIssuesSources.impl(impls))
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

  defp with_issues(issues) do
    impls = %{fetch_all_issues: fn _ -> {:ok, issues} end}
    container = container(impls)
    service = Service.new(IssuesStore)
    assert {:ok, %{impl: %IssuesStore{} = store}, _} = Service.build(service, container)
    store
  end

  defp compile_query(yaml) when is_binary(yaml) do
    yaml
    |> YamlElixir.read_from_string!()
    |> compile_query()
  end

  @issue_keys Tonka.Utils.struct_binary_keys(Tonka.Data.Issue)

  defp compile_query(map) when is_map(map) do
    MQL.compile!(map, as_atoms: @issue_keys)
  end

  test "T.MQLGroups defaults to zero for limits" do
    groups =
      """
      - title: Lim1
        query:
          labels: 'todo'
        limit: 22
      - title: Nolimit
        query:
          labels: 'todo'
      """
      |> YamlElixir.read_from_string!()
      |> Tonka.T.MQLGroups.cast_input()

    assert {:ok, [%{limit: 22}, %{limit: -1}]} = groups
  end

  test "the issues store will return a list for a query" do
    query =
      compile_query("""
        labels: 'todo'
      """)

    store = with_issues([])
    assert {:ok, list} = IssuesStore.mql_query(store, query, :infinity)
  end

  defp rand_sid, do: :erlang.unique_integer([:positive]) |> to_string()
  defp rand_str, do: :crypto.strong_rand_bytes(6) |> Base.encode64()

  defp issue_with_labels(labels) do
    %Issue{
      labels: labels,
      id: rand_sid(),
      iid: rand_sid(),
      title: rand_str(),
      url: rand_str(),
      status: :open
    }
  end

  test "the issues store will return a list of issues" do
    query =
      compile_query("""
        labels: 'todo'
      """)

    store = with_issues([issue_with_labels(["todo"]), issue_with_labels(["other"])])
    assert {:ok, [%Issue{labels: ["todo"]}]} = IssuesStore.mql_query(store, query)
  end

  test "the issues store will respect the limit" do
    query =
      compile_query("""
        labels: 'todo'
      """)

    store = with_issues([issue_with_labels(["todo"]), issue_with_labels(["todo"])])
    assert {:ok, [%Issue{labels: ["todo"]}]} = IssuesStore.mql_query(store, query, 1)
  end
end

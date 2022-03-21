defmodule Tonka.IssuesStoreTest do
  use ExUnit.Case, async: true

  alias Tonka.Core.Service
  alias Tonka.Services.IssuesStore

  defmodule TestIssuesSources do
    @derive Tonka.Services.IssuesSource
    defstruct [:issues]
  end

  test "the issues store is a service" do
    assert Tonka.Core.Reflection.implements_behaviour?(IssuesStore, Service)
  end

  test "the issues store can be built as a service" do
    service = Service.new(IssuesStore)
  end

  # test "an issues store requires an issue source" do
  # assert {:ok, _} = IssuesStore.build()
  # end
end

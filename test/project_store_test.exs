defmodule Tonka.ProjectStoreTest do
  use ExUnit.Case, async: true

  alias Tonka.Data.ProjectInfo
  alias Tonka.Services.ProjectStore
  alias Tonka.Services.ProjectStore.Record
  alias Tonka.Services.ProjectStore.Backend
  alias Tonka.Core.Container

  @component inspect(__MODULE__)

  test "building a project info" do
    assert %ProjectInfo{id: "test", storage_dir: "var/projects/test"} =
             ProjectInfo.new(id: "test", storage_dir: "var/projects/test")
  end

  defmodule MapBackend do
    @derive Backend
    defstruct [:funs]

    require(Tonka.Test.Stubber).stub_funs(Backend)

    def impl_with(funs) when is_map(funs) do
      %__MODULE__{funs: funs}
    end
  end

  test "a new project store can be created" do
    store = ProjectStore.new("test", backend_stub(%{}))
    assert is_struct(store, ProjectStore)
  end

  test "a record is passed to the backend and read from the backend" do
    ref = make_ref

    impls = %{
      put: fn _, project_id, component, key, value ->
        send(self(), {ref, project_id, component, key, value})
        :ok
      end,
      get: fn _, project_id, component, key ->
        case key do
          "madeup" -> %{some: "made up value"}
          _ -> nil
        end
      end
    }

    store = ProjectStore.new("test", backend_stub(impls))
    ProjectStore.put(store, @component, "mykey", %{some: "value"})
    assert_receive {^ref, "test", @component, "mykey", %{some: "value"}}

    assert %{some: "made up value"} == ProjectStore.get(store, @component, "madeup")
    assert nil == ProjectStore.get(store, @component, "not existing")

    assert %{some: "default"} ==
             ProjectStore.get(store, @component, "not existing", %{some: "default"})
  end

  defp test_info do
    ProjectInfo.new(id: "test", storage_dir: "var/projects/test")
  end

  defp backend_stub(funs) when is_map(funs) do
    MapBackend.impl_with(funs)
  end

  defp backend_stub(funs) when is_list(funs) do
    true = Keyword.keyword?(funs)
    MapBackend.impl_with(Map.new(funs))
  end
end

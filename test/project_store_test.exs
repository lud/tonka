defmodule Tonka.ProjectStoreTest do
  alias Tonka.Core.Container
  alias Tonka.Data.ProjectInfo
  alias Tonka.Services.ProjectStore
  alias Tonka.Services.ProjectStore.Backend
  alias Tonka.Services.ProjectStore.CubDBStore
  alias Tonka.Services.ProjectStore.Record
  use ExUnit.Case, async: true

  @component "MyComponent"

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

    store =
      ProjectStore.new(
        "test",
        backend_stub(
          put: fn _, project_id, component, key, value ->
            send(self(), {ref, project_id, component, key, value})
            :ok
          end,
          get: fn _, project_id, component, key ->
            case key do
              "madeup" -> %{some: "made up value"}
              _ -> nil
            end
          end,
          get_and_update: fn _, project_id, component, key, f ->
            {v, _} = f.("get_and_update_fake")
            {:ok, v}
          end,
          delete: fn _, _, _, _ -> :ok end
        )
      )

    ProjectStore.put(store, @component, "mykey", %{some: "value"})
    assert_receive {^ref, "test", @component, "mykey", %{some: "value"}}

    assert %{some: "made up value"} == ProjectStore.get(store, @component, "madeup")
    assert nil == ProjectStore.get(store, @component, "not existing")

    assert %{some: "default"} ==
             ProjectStore.get(store, @component, "not existing", %{some: "default"})

    assert {:ok, :returned} =
             ProjectStore.get_and_update(store, @component, "mykey", fn stored ->
               assert stored == "get_and_update_fake"
               {:returned, :ignored}
             end)

    assert :ok = ProjectStore.delete(store, @component, "mykey")
  end

  defp backend_stub(funs) when is_map(funs) do
    MapBackend.impl_with(funs)
  end

  defp backend_stub(funs) when is_list(funs) do
    true = Keyword.keyword?(funs)
    MapBackend.impl_with(Map.new(funs))
  end

  test "the CubDB implementation works" do
    # do not set auto_compact: false, auto_file_sync: false outside of tests
    assert {:ok, cub} =
             CubDB.start_link(
               data_dir: "var/projects/test/stores/project-store-test",
               auto_compact: true,
               auto_file_sync: true
             )

    CubDB.clear(cub)

    backend = CubDBStore.new(cub)
    store = ProjectStore.new("test", backend)

    value = %{this: "is", a: %{"sub" => "map"}}
    updated = %{"a new" => :VALUE}

    assert :ok = ProjectStore.put(store, @component, "mykey", value)
    assert ^value = ProjectStore.get(store, @component, "mykey")

    assert %{hello: "world"} =
             ProjectStore.get(store, @component, "non existing", %{hello: "world"})

    assert {:ok, :returnval} =
             ProjectStore.get_and_update(store, @component, "mykey", fn v ->
               assert value == v
               {:returnval, updated}
             end)

    assert ^updated = ProjectStore.get(store, @component, "mykey")

    # assert that the cub store does not bother inserting the project id in the
    # store. This assertion is here to fail if we want to use a global db for
    # all projects.
    assert ^updated = CubDB.get(cub, {@component, "mykey"})

    assert :ok = ProjectStore.delete(store, @component, "mykey")
    assert nil == ProjectStore.get(store, @component, "mykey")

    assert nil == CubDB.get(cub, {@component, "mykey"})
  end
end

defmodule Tonka.CleanupTest do
  alias Tonka.Services.CleanupStore
  alias Tonka.Services.CleanupStore.CleanupParams
  alias Tonka.Services.ProjectStore
  alias Tonka.Services.ProjectStore.CubDBStore
  use ExUnit.Case, async: false

  defp project_store do
    assert {:ok, cub} =
             CubDB.start_link(
               data_dir: "var/projects/test/stores/cleanup-store-test",
               auto_compact: true,
               auto_file_sync: true
             )

    CubDB.clear(cub)

    backend = CubDBStore.new(cub)
    _store = ProjectStore.new("test", backend)
  end

  test "a cleanup store can be created" do
    assert %CleanupStore{} = CleanupStore.new(project_store())
  end

  defp get_store do
    CleanupStore.new(project_store())
  end

  test "a cleanup can be registered and deleted" do
    store = get_store()
    key = "mykey"
    data = %{some: "data"}
    ttl = 100
    assert :ok = CleanupStore.put(store, key, ttl, data)
    assert [] = CleanupStore.list_expired(store, key)
    Process.sleep(100)
    assert [{id, ^data}] = CleanupStore.list_expired(store, key)

    assert :ok = CleanupStore.delete_id(store, key, id)
    assert [] = CleanupStore.list_expired(store, key)
  end
end

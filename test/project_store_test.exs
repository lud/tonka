defmodule Tonka.ProjectStoreTest do
  alias Tonka.Core.Container
  alias Tonka.Services.ProjectStore
  alias Tonka.Services.ProjectStore.Backend
  alias Tonka.Services.ProjectStore.CubDBBackend
  alias Tonka.Services.ProjectStore.Record
  use ExUnit.Case, async: true

  @component "MyComponent"

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
          put: fn _, prk, component, key, value ->
            send(self(), {ref, prk, component, key, value})
            :ok
          end,
          get: fn _, prk, component, key ->
            case key do
              "madeup" -> %{some: "made up value"}
              _ -> nil
            end
          end,
          get_and_update: fn _, prk, component, key, f ->
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

  defp get_cub do
    # do not set auto_compact: false, auto_file_sync: false outside of tests
    cub =
      start_supervised!(
        {CubDB,
         data_dir: "var/projects/test/stores/project-store-test",
         auto_compact: true,
         auto_file_sync: true}
      )

    CubDB.clear(cub)
    cub
  end

  defp get_store(cub) do
    backend = CubDBBackend.new(cub)
    ProjectStore.new("test", backend)
  end

  test "the CubDB implementation works" do
    cub = get_cub()
    store = get_store(cub)

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

  test "pop keys from the project store in CubDB" do
    cub = get_cub()
    store = get_store(cub)
    value = %{my: "map"}
    key = "poppable"
    assert :ok = ProjectStore.put(store, @component, key, value)
    assert ^value = ProjectStore.get(store, @component, key)

    assert {:ok, ^value} = ProjectStore.get_and_update(store, @component, key, fn _ -> :pop end)

    assert nil == ProjectStore.get(store, @component, key)
  end
end

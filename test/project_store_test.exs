defmodule Tonka.ProjectStoreTest do
  use ExUnit.Case, async: true

  alias Tonka.Data.ProjectInfo
  alias Tonka.Services.ProjectStore
  alias Tonka.Services.ProjectStore.Backend
  alias Tonka.Core.Container

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
    assert %ProjectStore{backend: %MapBackend{}} = ProjectStore.new(backend_stub(%{}))
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

defmodule Tonka.CredentialsTest do
  alias Tonka.Services.Credentials
  alias Tonka.Services.Credentials.JsonFileCredentials
  use ExUnit.Case, async: true

  @fixture "test/fixtures/creds.json"

  defp fixture_path, do: Path.join(File.cwd!(), @fixture)
  defp fixture_json, do: File.read!(fixture_path())
  defp fixture_data, do: Jason.decode!(fixture_json())

  test "assert Tonka.Services.Credentials is a protocol" do
    case Credentials.__protocol__(:impls) do
      {:consolidated, _} -> assert true
      :not_consolidated -> assert true
      _ -> flunk("protocol not implemented")
    end
  end

  test "loading JsonFileCredentials from path, json or data" do
    from_path = JsonFileCredentials.from_path!(fixture_path())
    from_json = JsonFileCredentials.from_json!(fixture_json())
    from_data = JsonFileCredentials.new(fixture_data())

    assert from_path == from_json
    assert from_path == from_data
  end

  test "loading JsonFileCredentials from path with result tuple" do
    from_path = JsonFileCredentials.from_path!(fixture_path())
    assert {:ok, ^from_path} = JsonFileCredentials.from_path(fixture_path())
    from_json = JsonFileCredentials.from_json!(fixture_json())
    from_data = JsonFileCredentials.new(fixture_data())

    assert from_path == from_json
    assert from_path == from_data
  end

  test "loading JsonFileCredentials returns a struct" do
    store = JsonFileCredentials.from_path!(fixture_path())
    assert match?(%JsonFileCredentials{}, store)
  end

  test "JsonFileCredentials implements Credentials" do
    {:consolidated, impls} = Credentials.__protocol__(:impls)
    assert JsonFileCredentials in impls
    store = JsonFileCredentials.new(%{"k" => "v"})
    assert JsonFileCredentials.get_string(store, "k") == Credentials.get_string(store, "k")
  end

  test "can load fixtures" do
    data = fixture_data()
    assert data["simple_path"] == "simple_path_value"
    assert data["nested"]["path"] == "nested_path_value"
    assert data["deep"]["nested"]["path"] == "deep_nested_path_value"
    assert data["deep"]["nested"]["sibling"] == "deep_nested_sibling_value"
  end

  test "reading a value" do
    store = JsonFileCredentials.from_path!(fixture_path())
    assert {:ok, "simple_path_value"} = Credentials.get_string(store, "simple_path")
  end
end

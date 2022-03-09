defmodule Tonka.CredentialsTest do
  alias Tonka.Service.Credentials
  alias Tonka.Core.Container
  alias Tonka.Service.Credentials.JsonFileCredentials
  use ExUnit.Case, async: true

  @fixture "test/fixtures/creds.json"

  defp fixture_path, do: Path.join(File.cwd!(), @fixture)
  defp fixture_json, do: File.read!(fixture_path)
  defp fixture_data, do: Jason.decode!(fixture_json())

  test "can load fixtures" do
    data = fixture_data()
    assert data["simple_path"] == "simple_path_value"
    assert data["nested"]["path"] == "nested_path_value"
    assert data["deep"]["nested"]["path"] == "deep_nested_path_value"
    assert data["deep"]["nested"]["sibling"] == "deep_nested_sibling_value"
  end

  test "assert Tonka.Service.Credentials is a protocol" do
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
end

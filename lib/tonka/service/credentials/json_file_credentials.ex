defmodule Tonka.Service.Credentials.JsonFileCredentials do
  @enforce_keys [:data]
  defstruct @enforce_keys

  @type level :: binary | %{optional(binary) => level}
  @type t :: %__MODULE__{data: level}

  @spec new(%{optional(binary) => level}) :: t
  def new(data) when is_map(data) do
    struct!(__MODULE__, data: data)
  end

  def from_path!(path), do: from_json!(File.read!(path))
  def from_json!(json), do: new(Jason.decode!(json))
end

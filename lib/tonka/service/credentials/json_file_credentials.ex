defmodule Tonka.Service.Credentials.JsonFileCredentials do
  @enforce_keys [:data]
  defstruct @enforce_keys

  @type level :: binary | %{optional(binary) => level}
  @type t :: %__MODULE__{data: level}

  @spec new(%{optional(binary) => level}) :: t
  def new(data) when is_map(data) do
    struct!(__MODULE__, data: data)
  end

  def from_path!(path) when is_binary(path) do
    case from_path(path) do
      {:ok, store} -> store
      # do not give hints about storage location for credentials
      {:error, _reason} -> raise ArgumentError, "could not load credentials"
    end
  end

  def from_path(path) when is_binary(path) do
    case File.read(path) do
      {:ok, json} -> from_json(json)
      {:error, _} = err -> err
    end
  end

  def from_json!(json) when is_binary(json) do
    case from_json(json) do
      {:ok, store} -> store
      # do not give hints about storage location for credentials
      {:error, _reason} -> raise ArgumentError, "could not load credentials"
    end
  end

  def from_json(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, data} when is_map(data) -> {:ok, new(data)}
      {:ok, _} -> {:error, :not_a_map}
      {:error, _} = err -> err
    end
  end
end

defimpl Tonka.Service.Credentials, for: Tonka.Service.Credentials.JsonFileCredentials do
end

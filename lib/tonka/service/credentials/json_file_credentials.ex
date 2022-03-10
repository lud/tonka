defmodule Tonka.Service.Credentials.JsonFileCredentials do
  @enforce_keys [:data]
  @derive Tonka.Service.Credentials
  defstruct @enforce_keys

  @type level :: binary | %{optional(binary) => level}
  @type t :: %__MODULE__{data: level}

  @spec new(%{optional(binary) => level}) :: t
  def new(data) when is_map(data) do
    struct!(__MODULE__, data: data)
  end

  @spec from_path!(binary) :: t
  def from_path!(path) when is_binary(path) do
    case from_path(path) do
      {:ok, store} -> store
      # do not give hints about storage location for credentials
      {:error, _reason} -> raise ArgumentError, "could not load credentials"
    end
  end

  @spec from_path(binary) :: {:ok, t} | {:error, term}
  def from_path(path) when is_binary(path) do
    case File.read(path) do
      {:ok, json} -> from_json(json)
      {:error, _} = err -> err
    end
  end

  @spec from_json!(binary) :: t
  def from_json!(json) when is_binary(json) do
    case from_json(json) do
      {:ok, store} -> store
      # do not give hints about storage location for credentials
      {:error, _reason} -> raise ArgumentError, "could not load credentials"
    end
  end

  @spec from_json(binary) :: {:ok, t} | {:error, term}
  def from_json(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, data} when is_map(data) -> {:ok, new(data)}
      {:ok, _} -> {:error, :not_a_map}
      {:error, _} = err -> err
    end
  end

  @spec get_string(t, binary) :: {:ok, binary} | {:error, :not_a_string | :not_found | term}
  def get_string(%__MODULE__{data: data}, path) do
    path = expand_path(path)

    case get_in(data, path) do
      nil -> {:error, :not_found}
      value when is_binary(value) -> {:ok, value}
      _ -> {:error, :not_a_string}
    end
  end

  defp expand_path(path) when is_list(path), do: path
  defp expand_path(path) when is_binary(path), do: String.split(path, ".")
end

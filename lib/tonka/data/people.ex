defmodule Tonka.Data.People do
  @moduledoc """
  Represents a group of `Tonka.Data.Person`
  """

  use Tonka.Core.Service
  alias Tonka.Data.Person

  @impl true
  def build(_, params) do
    with {:ok, all} <- Ark.Ok.map_ok(params, &validate_person/1) do
      {:ok, new(all)}
    end
  end

  def validate_person(%Person{} = p),
    do: {:ok, p}

  def ensure_all_people(other),
    do: {:error, {:invalid_person, other}}

  @impl true
  def cast_params(raw) when is_map(raw) do
    raw
    |> Enum.map(fn
      {id, nil} -> %{"id" => id}
      {id, person} -> Map.put(person, "id", id)
    end)
    |> Ark.Ok.map_ok(&Tonka.Data.Person.denormalize/1)
  end

  def cast_params(raw) do
    {:error, "people service expecs a map of persons as its params, got: #{inspect(raw)}"}
  end

  @impl true
  def configure(config) do
    config
  end

  @impl true
  def service_type, do: __MODULE__

  defstruct people: []

  @type t :: %__MODULE__{people: [Tonka.Data.Person.t()]}

  def new(people) do
    %__MODULE__{people: people}
  end

  def fetch(%{people: ps}, id) do
    ps |> Enum.find(&(&1.id == id)) |> cast_found()
  end

  defp cast_found(nil), do: :error
  defp cast_found(%{id: _} = p), do: {:ok, p}

  def find_by(%{people: ps}, key, value) when is_binary(key) do
    ps
    |> Enum.find(fn %{props: props} ->
      is_map_key(props, key) and Map.fetch!(props, key) == value
    end)
    |> cast_found()
  end
end

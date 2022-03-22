defmodule Tonka.Services.IssuesStore do
  use Tonka.Core.Service
  alias __MODULE__

  defstruct []

  # ---------------------------------------------------------------------------
  #  Service API
  # ---------------------------------------------------------------------------

  def cast_params(term) do
    {:ok, term}
  end

  def configure(config) do
    config
    |> Service.use_service(:source, Tonka.Services.IssuesSource)
  end

  def build(injects, params) do
    {:ok, %__MODULE__{}}
  end

  # ---------------------------------------------------------------------------
  #  Store API
  # ---------------------------------------------------------------------------

  def query_groups(%IssuesStore{}, groups) when is_list(groups) do
    {:ok, Enum.map(groups, fn _ -> [] end)}
  end
end

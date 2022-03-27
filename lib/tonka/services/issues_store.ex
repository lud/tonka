defmodule Tonka.Services.IssuesStore do
  use Tonka.Core.Service
  alias Tonka.Core.Query.MQL
  alias Tonka.Services.IssuesSource
  alias __MODULE__
  @enforce_keys [:source]
  defstruct @enforce_keys

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

  def build(injects, _params) do
    {:ok, %__MODULE__{source: injects.source}}
  end

  # ---------------------------------------------------------------------------
  #  Store API
  # ---------------------------------------------------------------------------

  def mql_query(store, query) do
    mql_query(store, query, :infinity)
  end

  def mql_query(store, query, -1) do
    mql_query(store, query, :infinity)
  end

  def mql_query(store, _, _) when not is_struct(store, IssuesStore) do
    raise ArgumentError, "expected a store, got: #{inspect(store)}"
  end

  def mql_query(_, query, _) when not is_map(query) do
    raise ArgumentError, "expected a map as query, got: #{inspect(query)}"
  end

  def mql_query(_, _, limit) when not (is_integer(limit) or :infinity == limit) do
    raise ArgumentError, "expected an integer or :infinity as limit, got: #{inspect(limit)}"
  end

  def mql_query(%IssuesStore{} = store, query, limit) do
    run_mql(store, query, limit)
  end

  def run_mql(%IssuesStore{source: source}, query, limit) do
    with {:ok, issues} <- IssuesSource.fetch_all_issues(source) do
      {_, filtered} =
        Enum.reduce_while(issues, {0, []}, fn issue, {size, acc} ->
          cond do
            size >= limit ->
              {:halt, {size, acc}}

            MQL.match?(query, issue) ->
              {:cont, {size + 1, [issue | acc]}}

            :else ->
              {:cont, {size, acc}}
          end
        end)

      {:ok, filtered}
    end
  end
end

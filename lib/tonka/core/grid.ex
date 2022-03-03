defmodule Tonka.Core.Grid do
  alias __MODULE__

  @moduledoc """
  A grid is an execution context for multiple operations.
  """

  @enforce_keys [:specs, :outputs, :states]
  defstruct @enforce_keys

  def new do
    %Grid{specs: %{}, outputs: %{}, states: %{}}
  end

  def add_operation(grid, key, module, spec \\ %{})

  def add_operation(%Grid{specs: specs}, key, _module, _spec) when is_map_key(specs, key) do
    raise ArgumentError, "an operation with the key #{inspect(key)} is already defined"
  end

  def add_operation(%Grid{specs: specs} = grid, key, module, spec)
      when is_binary(key) and is_atom(module) do
    spec = cast_spec(module, spec)
    specs = Map.put(specs, key, spec)
    %Grid{grid | specs: specs}
  end

  defp cast_spec(module, spec) when is_list(spec) do
    cast_spec(module, Map.new(spec))
  end

  defp cast_spec(module, spec) when is_map(spec) do
    spec
    |> Map.put(:module, module)
    |> Map.put_new(:from, %{})
    |> Map.put_new(Tonka.T.Params, %{})
  end

  def run(%Grid{} = grid, input) do
    outputs = %{input: input}
    states = start_states(grid.specs)
    grid = %Grid{grid | outputs: outputs, states: states}
    run(grid)
  end

  defp start_states(specs) do
    Enum.into(specs, %{}, fn {key, _} -> {key, :uninitialized} end)
  end

  defp run(grid) do
    case find_runnable(grid) do
      {:ok, key} -> grid |> call_op(key) |> run()
      :none -> {:done, grid}
    end
  end

  defp call_op(%{specs: specs, outputs: outputs, states: states} = grid, key) do
    inputs = build_input(grid, key)
    %{module: module, params: params} = Map.fetch!(specs, key)
    output = module.call(inputs, %{Tonka.T.Params => params})

    %Grid{
      grid
      | states: Map.put(states, key, :called),
        outputs: Map.put(outputs, key, output)
    }
  end

  defp find_runnable(%{specs: specs, outputs: outputs, states: states}) do
    states
    |> Enum.filter(fn {_, state} -> state == :uninitialized end)
    |> Enum.map(fn {key, _} -> {key, Map.fetch!(specs, key)} end)
    |> Enum.filter(fn {_key, %{from: from}} ->
      from_keys = Map.values(from)
      Enum.all?(from_keys, &Map.has_key?(outputs, &1))
    end)
    |> case do
      [{key, _} | _] -> {:ok, key}
      [] -> :none
    end
  end

  defp build_input(%{outputs: outputs, specs: specs}, key) do
    %{from: from} = Map.fetch!(specs, key)
    Enum.into(from, %{}, fn {key, source} -> {key, Map.fetch!(outputs, source)} end)
  end
end

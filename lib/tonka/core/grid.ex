defmodule Tonka.Core.Grid do
  alias __MODULE__

  @moduledoc """
  A grid is an execution context for multiple operations.
  """

  @enforce_keys [:specs]
  defstruct @enforce_keys

  def new do
    %Grid{specs: %{}}
  end

  def add_operation(grid, key, module)

  def add_operation(%Grid{specs: specs}, key, _module) when is_map_key(specs, key) do
    raise ArgumentError, "an operation with the key #{inspect(key)} is already defined"
  end

  def add_operation(%Grid{specs: specs} = grid, key, module)
      when is_binary(key) and is_atom(module) do
    specs = Map.put(specs, key, module)
    %Grid{grid | specs: specs}
  end

  def run(%Grid{}) do
  end
end

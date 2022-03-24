defmodule Tonka.Core.Booklet do
  alias __MODULE__
  alias Tonka.Core.Booklet.Block

  defstruct blocks: [], title: "Booklet Title", assigns: %{}

  @type t :: %Booklet{}

  @spec from_blocks(list) :: {:ok, Booklet.t()} | {:error, term}
  def from_blocks(blocks) when is_list(blocks) do
    blocks
    |> splat_list()
    |> Block.cast_blocks()
    |> case do
      {:ok, blocks} -> {:ok, %Booklet{blocks: blocks}}
      {:error, _} = err -> err
    end
  end

  def from_blocks!(blocks) do
    case from_blocks(blocks) do
      {:ok, blocks} ->
        blocks

      {:error, %{__exception__: true} = e} ->
        raise e

      {:error, reason} ->
        raise "could not build block: #{inspect(reason)}"
    end
  end

  def cast_input(input) do
    Tonka.Core.Booklet.InputCaster.cast_input(input)
  end

  defmodule CastError do
    defexception [:reason]

    def message(%{reason: {:unknown_prop, module, key, value}}) do
      "unknown property #{inspect(key)} for block #{module}"
    end
  end

  @doc """
  Flattens the list and removes all `nil` entries from the result.
  This function is automatically used when calling `from_blocks/1`.

  Useful to build a list of blocks with conditional blocks:
    - nil can be returned when building an unnecessary block
    - building blocks from nested structures can return an nested list as it
      will be flattened.
  """
  def splat_list(list) when is_list(list) do
    list
    |> Enum.map(fn
      %Booklet{} = nested -> nested.blocks
      other -> other
    end)
    |> :lists.flatten()
    |> Enum.reject(fn
      nil -> true
      _ -> false
    end)
  end

  def assign(%Booklet{assigns: current} = bl, assigns)
      when is_list(assigns)
      when is_map(assigns) do
    %Booklet{bl | assigns: Enum.into(current, assigns)}
  end
end

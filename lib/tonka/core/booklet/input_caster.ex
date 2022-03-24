defmodule Tonka.Core.Booklet.InputCaster do
  def cast_input(list) when is_list(list) do
    Ark.Ok.map_ok(list, &cast_block/1)
  end

  def cast_input(nil) do
    {:ok, []}
  end

  def cast_input(other) do
    {:error, "expected the input to be a list, got: #{inspect(other)}"}
  end

  defp cast_block(%{}) do
    {:ok, %{}}
  end
end

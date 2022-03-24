defmodule Tonka.Core.Booklet.InputCaster do
  alias Tonka.Core.Booklet

  alias Tonka.Core.Booklet.Blocks.Header
  alias Tonka.Core.Booklet.Blocks.Mrkdwn
  alias Tonka.Core.Booklet.Blocks.PlainText
  alias Tonka.Core.Booklet.Blocks.RichText
  alias Tonka.Core.Booklet.Blocks.Section

  @spec cast_input(list(map | binary)) :: Booklet.t()
  def cast_input(list) when is_list(list) do
    case Ark.Ok.map_ok(list, &cast_block/1) do
      {:ok, blocks} -> Booklet.from_blocks(blocks)
      {:error, _} = err -> err
    end
  end

  def cast_input(nil) do
    cast_input([])
  end

  def cast_input(other) do
    {:error, "expected the input to be a list, got: #{inspect(other)}"}
  end

  defp cast_block(%{"mrkdwn" => mrkdwn}) do
    Mrkdwn.cast(mrkdwn: mrkdwn)
  end

  defp cast_block(%{"plaintext" => plaintext}) do
    PlainText.cast(text: plaintext)
  end

  defp cast_block(%{"header" => text}) when is_binary(text) do
    Header.cast(text: text)
  end
end

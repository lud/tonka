defmodule Tonka.RichTextTest do
  use ExUnit.Case, async: true
  alias Tonka.Core.Booklet.Blocks.RichText

  test "can validate a richtext" do
    valids = [
      # a binary is valid. It will be treated as a raw string
      "hello",
      {:strong, "this is important"},
      {:em, "this is noticeable"},
      {:datetime, DateTime.utc_now()},
      {:strike, "this is wrong"},
      {:link, "http://example.com", "Some link"},
      [
        "some ",
        {:strong, ["NESTED", {:em, "data"}]},
        " ",
        {:link, "http://example.com", ["and a ", {:em, "link"}]}
      ],
      {:ul,
       [
         {:link, "http://example.com", "first item"},
         "second item",
         {:ul, ["nested", {:em, "list"}]}
       ]}
    ]

    Enum.map(valids, fn data ->
      assert {:ok, _} = Tonka.Core.Booklet.Block.cast_block({RichText, data: data})
    end)
  end
end

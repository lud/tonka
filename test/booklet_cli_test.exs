defmodule Tonka.BookletCliTest do
  use ExUnit.Case, async: true

  alias Tonka.Core.Booklet
  alias Tonka.Core.Booklet.Blocks.Header
  alias Tonka.Core.Booklet.Blocks.Mrkdwn
  alias Tonka.Core.Booklet.Blocks.PlainText
  alias Tonka.Core.Booklet.Blocks.RichText
  alias Tonka.Core.Booklet.Blocks.Section

  alias Tonka.Core.Booklet.CliRenderer

  test "a booklet can be created" do
    assert {:ok, booklet} =
             Booklet.from_blocks([
               Header.new(text: "Hello"),
               PlainText.new(text: "This is a simple test.")
             ])

    rendered = CliRenderer.render!(booklet)

    expected =
      """
      # Hello

      This is a simple test.
      """
      |> String.trim()

    assert expected == rendered
  end

  test "CLI can render richtext" do
    # if nothing throws then the test is considered OK. We will often tweak the
    # rendering because the CLI is only used for dev, to we will not actually
    # assert that the output matches things.

    booklet =
      Booklet.from_blocks!([
        Header.new(text: "Rich text test"),
        RichText.new(
          data: [
            # a binary is valid. It will be treated as a raw string
            "hello ",
            {:strong, "this is important "},
            {:em, "this is noticeable "},
            "\n",
            ["this is a date: ", {:datetime, DateTime.utc_now()}, ", "],
            "\n",
            [
              "this also in italics: ",
              {:em, [DateTime.utc_now(), ", I ", {:strong, "love"}, " italics!"]},
              ", "
            ],
            {:strike, "this is wrong"},
            ", ",
            {:link, "http://example.com", "Here Is Some link, "},
            [
              "some ",
              {:strong, ["NESTED ", {:em, "data "}]},
              " ",
              {:link, "http://example.com", [" and another ", {:em, "link"}]},
              ", "
            ],
            {:ul,
             [
               {:link, "http://example.com", "first item"},
               "second item",
               {:ul, ["nested", {:em, "list"}]}
             ]},
            [
              "not strong but ",
              {:strong, {:strong, {:strong, "SUUUUPER STRONG !!"}}},
              " alright?"
            ]
          ]
        )
      ])

    rendered = CliRenderer.render!(booklet)

    IO.puts(rendered)
    # flush IO
    IO.puts("")
  end
end

defmodule Tonka.BookletTest do
  use ExUnit.Case, async: true

  alias Tonka.Core.Booklet
  alias Tonka.Core.Booklet.Blocks.Header
  alias Tonka.Core.Booklet.Blocks.Mrkdwn
  alias Tonka.Core.Booklet.Blocks.PlainText
  alias Tonka.Core.Booklet.Blocks.RichText
  alias Tonka.Core.Booklet.Blocks.Section

  alias Tonka.Core.Booklet.CliRenderer

  test "a booklet can accept another booklet as a block" do
    {:ok, content} =
      Booklet.from_blocks([
        PlainText.new(text: "This is the content.")
      ])

    {:ok, wrapper} =
      Booklet.from_blocks([
        Header.new(text: "This is a header"),
        PlainText.new(text: "This is an introduction."),
        content,
        PlainText.new(text: "This is the footer.")
      ])

    {:ok, expected} =
      Booklet.from_blocks([
        Header.new(text: "This is a header"),
        PlainText.new(text: "This is an introduction."),
        PlainText.new(text: "This is the content."),
        PlainText.new(text: "This is the footer.")
      ])

    assert expected == wrapper

    rendered = CliRenderer.render!(wrapper)

    IO.puts(rendered)
    IO.puts("")
  end
end

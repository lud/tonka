defmodule Tonka.BookletTest do
  use ExUnit.Case, async: true
  import Tonka.Utils
  alias Tonka.Core.Booklet
  alias Tonka.Core.Booklet.InputCaster
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
  end

  test "casting empty elements as booklets" do
    assert {:ok, %Booklet{blocks: []}} = InputCaster.cast_input([])
    assert {:ok, %Booklet{blocks: []}} = InputCaster.cast_input(nil)
  end

  test "casting a list of blocks" do
    booklet =
      """
      - header: Hello!
      - mrkdwn: |-
          This is *nice*.

          Though I'd rather not use embedded YAML for those tests!
      - plaintext: >
          This is some plaintext
          but it does'nt have newlines
      """
      |> yaml!
      |> InputCaster.cast_input()
      |> Ark.Ok.uok!()

    CliRenderer.render!(booklet) |> IO.puts()

    assert [%Header{}, %Mrkdwn{}, %PlainText{}] = booklet.blocks
  end
end

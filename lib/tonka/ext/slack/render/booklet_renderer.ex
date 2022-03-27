defmodule Tonka.Ext.Slack.Render.BookletRenderer do
  use TODO
  alias Tonka.Core.Booklet
  alias Tonka.Core.Booklet.Blocks
  alias Tonka.Ext.Slack.BlockKit, as: BK
  alias Tonka.Ext.Slack.Data.Post

  @impl Booklet.Renderer
  @spec render(Booklet.t()) ::
          {:ok, %Post{}} | {:error, term}

  def(render(%Booklet{} = booklet)) do
    blocks = render_blocks(booklet.blocks)
    {:ok, Post.new(booklet.title, blocks)}
  rescue
    e -> {:error, e}
  end

  defp render_blocks(blocks) do
    blocks
    |> Enum.map(&render_block/1)
    |> BK.block_list()
  end

  defp render_block(%Blocks.Header{text: text}) do
    BK.header(text)
  end

  defp render_block(%Blocks.Mrkdwn{mrkdwn: mrkdwn}) do
    BK.section(BK.mrkdwn(mrkdwn))
  end

  defp render_block(%Blocks.Section{
         header: header,
         content: content,
         footer: footer
       }) do
    # all props are richtext
    md = if header, do: rich_to_mrkdwn({:strong, header}) <> "\n", else: ""

    md = md <> rich_to_mrkdwn(content)

    [
      BK.section(BK.mrkdwn(md)),
      if(footer, do: BK.context([rich_to_mrkdwn(footer)]))
    ]
  end

  defp render_block(%struct{} = block) do
    raise ArgumentError,
      message: "unknown block type #{struct}"
  end

  defp rich_to_mrkdwn(richtext) do
    to_string(rich(richtext))
  end

  defp rich({:strong, sub} = tag) do
    "*#{without(sub, "*")}*"
  end

  defp rich(list) when is_list(list) do
    Enum.map(list, &rich/1)
  end

  @todo "rich must accept options to know the indent level of nested lists"
  defp rich({:ul, elems}) do
    md = [10, Enum.map(elems, fn el -> ["– ", rich(el), 10] end)]
  end

  defp rich({:link, url, text}) do
    BK.link(url, rich(text))
  end

  defp rich(bin) when is_binary(bin) do
    bin
  end

  defp rich(richtext) do
    raise ArgumentError,
      message: "unknown richtext element #{inspect(richtext)}"
  end

  defp without(str, char) when is_binary(str) and is_binary(char) do
    String.replace(str, char, "")
  end

  defp format_datetime(dt, format \\ "{date_short} {time}", url \\ nil) do
    unix = DateTime.to_unix(dt)

    link =
      case url do
        nil -> ""
        _ -> "^#{url}"
      end

    fallback = "UTC #{dt}"
    "<!date^#{unix}^#{format}#{link}|#{fallback}>"
  end
end

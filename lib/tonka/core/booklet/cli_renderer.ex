defmodule Tonka.Core.Booklet.CliRenderer do
  alias Tonka.Core.Booklet

  alias Tonka.Core.Booklet.Blocks.Header
  alias Tonka.Core.Booklet.Blocks.Mrkdwn
  alias Tonka.Core.Booklet.Blocks.PlainText
  alias Tonka.Core.Booklet.Blocks.RichText
  alias Tonka.Core.Booklet.Blocks.Section

  require IO.ANSI.Sequence
  IO.ANSI.Sequence.defsequence(:not_crossed_out, 29)

  @date_color :magenta
  @link_color :blue

  # "rc" (Rich Context) record to represent the wrapping of elements like strong, to known when to
  # reset brightness/color

  def render(booklet) do
    {:ok, render!(booklet)}
  rescue
    e -> {:error, e}
  end

  def render!(booklet) do
    ctx = base_context()

    booklet.blocks
    |> Enum.intersperse(:block_separator)
    |> Enum.map(&render_block(&1, ctx))
    |> :erlang.iolist_to_binary()
  end

  defp render_block(:block_separator, _) do
    "\n\n"
  end

  defp render_block(raw, _) when is_binary(raw) do
    raw
  end

  defp render_block(%Header{text: text}, _) do
    "# #{text}"
  end

  defp render_block(%PlainText{text: text}, _) do
    text
  end

  defp render_block(%Section{content: content, footer: footer, header: header}, ctx) do
    header = rich(header, ctx)
    content = rich(content, ctx)
    footer = rich(footer, ctx)

    [
      "-----------------------------------------------\n",
      header,
      ?\n,
      content,
      ?\n,
      footer,
      "\n-----------------------------------------------"
    ]
  end

  defp render_block(%RichText{data: data}, ctx) do
    rich(data, ctx)
  end

  defp incr(map, key) do
    Map.update!(map, key, &(&1 + 1))
  end

  defp put_color(map, color) do
    Map.update!(map, :colors, &[color | &1])
  end

  defp rich(list, ctx) when is_list(list) do
    Enum.map(list, &rich(&1, ctx))
  end

  defp rich(raw, _ctx) when is_binary(raw) do
    raw
  end

  defp rich({:strong, sub}, ctx) do
    ansi_wrap(sub, ctx, &wrap_strong/1)
  end

  defp rich({:em, sub}, ctx) do
    ansi_wrap(sub, ctx, &wrap_em/1)
  end

  defp rich({:strike, sub}, ctx) do
    ansi_wrap(sub, ctx, &wrap_strike/1)
  end

  defp rich({:datetime, %DateTime{} = dt}, ctx) do
    rich(dt, ctx)
  end

  defp rich(%DateTime{} = dt, ctx) do
    sub = DateTime.to_string(dt)
    ansi_wrap(sub, ctx, &wrap_color(&1, @date_color))
  end

  defp rich({:link, href, sub}, ctx) do
    link = ansi_wrap(href, ctx, &wrap_color(&1, @link_color))
    [rich(sub, ctx), " ", ?(, link, ?)]
  end

  defp rich({:ul, sub}, ctx) do
    Enum.map(sub, fn sub -> ["* ", rich(sub, ctx), ?\n] end)
  end

  defp rich(other, _) do
    """

      defp rich(#{inspect(other)}, ctx) do

      end
    """
    |> IO.puts()

    # raise ArgumentError, "unknown rich text element: #{inspect(other)}"
    []
  end

  # defp ansi_wrap(sub, ctx, start, stop) do
  #   {tag, ctx} = start.(ctx)
  #   main = rich(sub, ctx)
  #   {end_tag, _ctx} = stop.(ctx)
  #   [tag, main, end_tag]
  # end

  defp ansi_wrap(sub, ctx, start_stop) do
    {start_tag, end_tag, sub_ctx} = start_stop.(ctx)
    main = rich(sub, sub_ctx)
    [start_tag, main, end_tag]
  end

  defp wrap_strong(%{strong: 0} = ctx) do
    {IO.ANSI.bright(), restart_tags(ctx), incr(ctx, :strong)}
  end

  defp wrap_strong(ctx) do
    {[], [], incr(ctx, :strong)}
  end

  defp wrap_em(%{em: 0} = ctx) do
    {IO.ANSI.italic(), IO.ANSI.not_italic(), incr(ctx, :em)}
  end

  defp wrap_em(ctx) do
    {[], [], incr(ctx, :em)}
  end

  defp wrap_strike(%{strike: 0} = ctx) do
    {IO.ANSI.crossed_out(), not_crossed_out(), incr(ctx, :strike)}
  end

  defp wrap_strike(ctx) do
    {[], [], incr(ctx, :strike)}
  end

  defp wrap_color(ctx, color) do
    {apply(IO.ANSI, color, []), restart_tags(ctx), put_color(ctx, color)}
  end

  defp base_context do
    %{strong: 0, colors: [], em: 0, strike: 0}
  end

  defp restart_tags(%{strong: strong, colors: colors}) do
    [
      IO.ANSI.normal(),
      case strong do
        0 -> []
        _ -> IO.ANSI.bright()
      end,
      case colors do
        [] -> IO.ANSI.default_color()
        [col] -> apply(IO.ANSI, col, [])
      end
    ]
  end
end

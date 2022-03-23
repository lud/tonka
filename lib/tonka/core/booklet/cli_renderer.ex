defmodule Tonka.Core.Booklet.CliRenderer do
  alias Tonka.Core.Booklet

  alias Tonka.Core.Booklet.Blocks.Header
  alias Tonka.Core.Booklet.Blocks.Mrkdwn
  alias Tonka.Core.Booklet.Blocks.PlainText
  alias Tonka.Core.Booklet.Blocks.RichText
  alias Tonka.Core.Booklet.Blocks.Section

  require IO.ANSI.Sequence
  IO.ANSI.Sequence.defsequence(:not_crossed_out, 29)

  # "rc" (Rich Context) record to represent the wrapping of elements like strong, to known when to
  # reset brightness/color

  def render(booklet) do
    {:ok, render!(booklet)}
  rescue
    e -> {:error, e}
  end

  def render!(booklet) do
    ctx = Map.new()

    [
      Enum.map(booklet.blocks, &render_block(&1, ctx))
    ]
    |> Booklet.splat_list()
    |> :erlang.iolist_to_binary()
  end

  defp render_block(%Header{text: text}, _) do
    """
    # #{text}

    """
  end

  defp render_block(%PlainText{text: text}, _) do
    text
  end

  defp render_block(%RichText{data: data}, _) do
    rich(data, rc())
  end

  defp incr(map, key) when is_map_key(map, key) do
    Map.update!(map, key, &(&1 + 1))
  end

  defp decr(map, key) when is_map_key(map, key) do
    Map.update!(map, key, fn n ->
      true = n > 0
      n - 1
    end)
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

  defp wrap_strong(%{strong: 0, colors: []} = ctx) do
    {IO.ANSI.bright(), IO.ANSI.normal(), incr(ctx, :strong)}
  end

  defp wrap_strong(%{strong: 0, colors: [color | _]} = ctx) do
    {IO.ANSI.bright(), [IO.ANSI.normal(), apply(IO.ANSI, color, [])], incr(ctx, :strong)}
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

  defp rc do
    %{strong: 0, colors: [], em: 0, strike: 0}
  end
end

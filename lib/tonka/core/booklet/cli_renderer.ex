defmodule Tonka.Core.Booklet.CliRenderer do
  alias Tonka.Core.Booklet

  alias Tonka.Core.Booklet.Blocks.Header
  alias Tonka.Core.Booklet.Blocks.Mrkdwn
  alias Tonka.Core.Booklet.Blocks.PlainText
  alias Tonka.Core.Booklet.Blocks.RichText
  alias Tonka.Core.Booklet.Blocks.Section

  require IO.ANSI.Sequence

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
    ansi_wrap(sub, ctx, &start_strong/1, &stop_strong/1)
  end

  defp rich({:em, sub}, ctx) do
    ansi_wrap(sub, ctx, &start_em/1, &stop_em/1)
  end

  defp rich({:strike, sub}, ctx) do
    ansi_wrap(sub, ctx, &start_strike/1, &stop_strike/1)
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

  defp ansi_wrap(sub, ctx, start, stop) do
    {tag, ctx} = start.(ctx)
    main = rich(sub, ctx)
    {end_tag, _ctx} = stop.(ctx)
    [tag, main, end_tag]
  end

  defp start_strong(%{strong: 0} = ctx) do
    {IO.ANSI.bright(), incr(ctx, :strong)}
  end

  defp start_strong(ctx) do
    {[], incr(ctx, :strong)}
  end

  defp stop_strong(%{strong: 1, colors: []} = ctx) do
    {IO.ANSI.normal(), decr(ctx, :strong)}
  end

  defp stop_strong(%{strong: 1, colors: [color | _]} = ctx) do
    {IO.ANSI.normal(), apply(IO.ANSI, color, []), decr(ctx, :strong)}
  end

  defp stop_strong(%{strong: n} = ctx) when n > 1 do
    {[], decr(ctx, :strong)}
  end

  defp start_em(%{em: 0} = ctx) do
    {IO.ANSI.italic(), incr(ctx, :em)}
  end

  defp start_em(ctx) do
    {[], incr(ctx, :em)}
  end

  defp stop_em(%{em: 1} = ctx) do
    {IO.ANSI.not_italic(), decr(ctx, :em)}
  end

  defp stop_em(%{em: n} = ctx) when n > 1 do
    {[], decr(ctx, :em)}
  end

  IO.ANSI.Sequence.defsequence(:not_crossed_out, 29)

  defp start_strike(%{strike: 0} = ctx) do
    {IO.ANSI.crossed_out(), incr(ctx, :strike)}
  end

  defp start_strike(ctx) do
    {[], incr(ctx, :strike)}
  end

  defp stop_strike(%{strike: 1} = ctx) do
    {not_crossed_out(), decr(ctx, :strike)}
  end

  defp stop_strike(%{strike: n} = ctx) when n > 1 do
    {[], decr(ctx, :strike)}
  end

  defp rc do
    %{strong: 0, colors: [], em: 0, strike: 0}
  end
end

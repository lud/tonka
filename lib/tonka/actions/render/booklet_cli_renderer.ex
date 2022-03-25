defmodule Tonka.Actions.Render.BookletCliRenderer do
  use Tonka.Core.Action
  alias Tonka.Data.IssuesGroup
  alias Tonka.Core.Booklet
  alias Tonka.Core.Booklet.Blocks.Header
  alias Tonka.Core.Booklet.Blocks.Mrkdwn
  alias Tonka.Core.Booklet.Blocks.PlainText
  alias Tonka.Core.Booklet.Blocks.RichText
  alias Tonka.Core.Booklet.Blocks.Section

  import Tonka.Gettext

  alias Tonka.Core.Booklet.CliRenderer

  def cast_params(term) do
    {:ok, term}
  end

  def return_type, do: Booklet

  def configure(config) do
    config
    |> Action.use_input(:booklet, Booklet)
  end

  def call(%{booklet: booklet}, _, _params) do
    with {:ok, rendered} <- CliRenderer.render(booklet) do
      IO.puts(rendered)
      {:ok, booklet}
    end
  end
end

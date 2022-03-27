defmodule Tonka.Actions.Render.BookletCliRenderer do
  alias Tonka.Core.Booklet
  alias Tonka.Core.Booklet.Blocks.Header
  alias Tonka.Core.Booklet.Blocks.Mrkdwn
  alias Tonka.Core.Booklet.Blocks.PlainText
  alias Tonka.Core.Booklet.Blocks.RichText
  alias Tonka.Core.Booklet.Blocks.Section
  alias Tonka.Core.Booklet.CliRenderer
  alias Tonka.Data.IssuesGroup
  import Tonka.Gettext
  use Tonka.Core.Action

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

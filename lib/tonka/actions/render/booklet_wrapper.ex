defmodule Tonka.Actions.Render.BookletWrapper do
  use Tonka.Core.Action
  alias Tonka.Data.IssuesGroup
  alias Tonka.Core.Booklet

  alias Tonka.Core.Booklet.Blocks.Header
  alias Tonka.Core.Booklet.Blocks.Mrkdwn
  alias Tonka.Core.Booklet.Blocks.PlainText
  alias Tonka.Core.Booklet.Blocks.RichText
  alias Tonka.Core.Booklet.Blocks.Section

  import Tonka.Gettext

  def cast_params(term) do
    {:ok, term}
  end

  def return_type, do: Booklet

  def configure(config) do
    config
    |> Action.use_input(:content, Booklet)
    |> Action.use_input(:above, Booklet)
    |> Action.use_input(:below, Booklet)
  end

  def call(%{content: content, above: above, below: below}, _, _params) do
    Booklet.from_blocks([above, content, below])
  end
end

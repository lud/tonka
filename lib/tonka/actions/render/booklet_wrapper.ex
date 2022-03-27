defmodule Tonka.Actions.Render.BookletWrapper do
  alias Tonka.Core.Booklet
  use Tonka.Core.Action

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

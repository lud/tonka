defmodule Tonka.Actions.Render.BookletWrapper do
  alias Tonka.Core.Booklet
  use Tonka.Core.Action

  require Hugs

  @params_schema Hugs.build_props()
                 |> Hugs.field(:title, type: :binary, required: true)

  def cast_params(params) do
    Hugs.denormalize(params, @params_schema)
  end

  def return_type, do: Booklet

  def configure(config) do
    config
    |> Action.use_input(:content, Booklet)
    |> Action.use_input(:above, Booklet)
    |> Action.use_input(:below, Booklet)
  end

  def call(%{content: content, above: above, below: below}, _, params) do
    with {:ok, booklet} <- Booklet.from_blocks([above, content, below]) do
      {:ok, Booklet.put_title(booklet, params.title)}
    end
  end
end

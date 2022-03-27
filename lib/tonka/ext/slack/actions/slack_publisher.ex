defmodule Tonka.Ext.Slack.Actions.SlackPublisher do
  alias Tonka.Core.Booklet
  alias Tonka.Core.Booklet.CliRenderer
  alias Tonka.Ext.Slack.Data.Post
  alias Tonka.Ext.Slack.Render.BookletRenderer
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
    with {:ok, %Post{} = post} <- BookletRenderer.render(booklet) do
      post |> IO.inspect(label: "post")
      {:ok, booklet}
    end
  end
end

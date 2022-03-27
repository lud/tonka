defmodule Tonka.Ext.Slack.Actions.SlackPublisher do
  alias Tonka.Core.Booklet
  alias Tonka.Core.Booklet.CliRenderer
  alias Tonka.Ext.Slack.Data.Post
  alias Tonka.Ext.Slack.Render.BookletRenderer
  alias Tonka.Ext.Slack.Services.SlackAPI
  require Hugs
  use Tonka.Core.Action

  @params_schema Hugs.build_props()
                 |> Hugs.field(:channel, type: :binary, required: true)

  def cast_params(term) do
    Hugs.denormalize(term, @params_schema)
  end

  def return_type, do: Booklet

  def configure(config) do
    config
    |> Action.use_input(:booklet, Booklet)
    |> Action.use_service(:slack, SlackAPI)
  end

  def call(%{booklet: booklet}, %{slack: slack}, %{channel: channel}) do
    with {:ok, %Post{} = post} <- BookletRenderer.render(booklet),
         {:ok, _} <- SlackAPI.send_chat_message(slack, post, channel) do
      {:ok, nil}
    end
  end
end

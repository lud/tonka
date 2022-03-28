defmodule Tonka.Ext.Slack.Actions.SlackPublisher do
  alias Tonka.Core.Booklet
  alias Tonka.Services.CleanupStore
  alias Tonka.Services.CleanupStore.CleanupParams
  alias Tonka.Ext.Slack.Data.Post
  alias Tonka.Ext.Slack.Render.BookletRenderer
  alias Tonka.Ext.Slack.Services.SlackAPI
  require Hugs
  use Tonka.Core.Action
  use Tonka.Project.ProjectLogger, as: Logger

  @params_schema Hugs.build_props()
                 |> Hugs.field(:channel, type: :binary, required: true)
                 |> Hugs.field(:cleanup, type: CleanupParams, required: false, default: nil)

  def cast_params(term) do
    Hugs.denormalize(term, @params_schema)
  end

  def return_type, do: Booklet

  def configure(config) do
    config
    |> Action.use_input(:booklet, Booklet)
    |> Action.use_service(:slack, SlackAPI)
    |> Action.use_service(:cleanup, CleanupStore)
  end

  def call(
        %{booklet: booklet} = inputs,
        %{slack: slack, cleanup: cleanup},
        %{channel: channel, cleanup: cleanup_params}
      ) do
    cleanup_key = cleanup_key(cleanup_params, inputs)

    run_cleanup(cleanup, cleanup_key, slack)

    with {:ok, %Post{} = post} <- BookletRenderer.render(booklet),
         {:ok, post_result} <- SlackAPI.send_chat_message(slack, post, channel) do
      register_cleanup(cleanup, cleanup_params, cleanup_key, post_result)
      {:ok, nil}
    end
  end

  defp cleanup_key(nil, _inputs) do
    nil
  end

  defp cleanup_key(cleanup_params, inputs) do
    CleanupStore.compute_key(__MODULE__, cleanup_params, inputs)
  end

  defp run_cleanup(_, nil, _) do
    :ok
  end

  defp run_cleanup(store, key, slack) do
    for {id, data} <- CleanupStore.list_expired(store, key) do
      case SlackAPI.cleanup_chat_message(slack, data) do
        :ok -> CleanupStore.delete_id(store, key, id)
      end
    end
  rescue
    e -> Logger.warn("coult not cleanup previous message: #{Exception.message(e)}")
  end

  defp register_cleanup(store, cleanup_params, key, %{cleanup: data} = _post_result) do
    CleanupStore.put(store, key, cleanup_params.ttl, data)
  rescue
    e -> Logger.warn("coult not register message for cleanup: #{Exception.message(e)}")
  end
end

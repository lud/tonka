defmodule Tonka.Ext.Slack.Services.SlackAPI do
  alias Tonka.Ext.Slack.Data.Post
  use Tonka.Project.ProjectLogger, as: Logger
  use TODO
  use Tonka.Core.Service

  @enforce_keys [:send_opts]
  defstruct @enforce_keys

  @type t :: %__MODULE__{send_opts: %{token: binary()}}

  @params_caster Hugs.build_props()
                 |> Hugs.field(:credentials, type: :binary, required: true)

  @pretty_json Mix.env() != :prod

  def new(opts) do
    struct!(__MODULE__, opts)
  end

  def cast_params(params) do
    Hugs.denormalize(params, @params_caster)
  end

  def configure(config) do
    config
    |> use_service(:credentials, Tonka.Services.Credentials)
  end

  def build(%{credentials: credentials}, %{credentials: path}) do
    case Tonka.Services.Credentials.get_string(credentials, path) do
      {:ok, token} -> {:ok, new(send_opts: %{token: token})}
      {:error, _} = err -> err
    end
  end

  @spec send_chat_message(%__MODULE__{}, Post.t(), channel :: binary) ::
          {:ok, cleanup_data :: term} | {:error, term}

  def send_chat_message(%__MODULE__{} = slack, %Post{} = post, channel) do
    message = build_message(slack, post)

    post_result = Slack.Web.Chat.post_message(channel, post.title, message)

    print_warnings(post_result)
    cast_send_result(post_result, channel, message.blocks)
  end

  defp print_warnings(result) do
    case result do
      %{"response_metadata" => %{"warnings" => warnings}} when is_list(warnings) ->
        Enum.each(warnings, fn w -> Elixir.Logger.warn("slack api warning: #{inspect(w)}") end)

      _ ->
        :ok
    end

    :ok
  end

  defp cast_send_result(result, channel, blocks) do
    case result do
      %{"ok" => true, "channel" => channel, "ts" => ts} ->
        {:ok,
         %{
           success_message: "Slack: Successfully posted to #{channel}",
           cleanup: %{channel: channel, ts: ts}
         }}

      %{"ok" => false, "error" => "channel_not_found"} ->
        {:error, {__MODULE__, {:channel_not_found, channel}}}

      %{"ok" => false, "error" => reason}
      when reason in ["invalid_blocks_format", "invalid_blocks"] ->
        Elixir.Logger.debug("""

        Invalid blocks JSON:

        #{blocks}
        """)

        {:error, reason}

      %{"error" => reason, "ok" => false} ->
        {:error, reason}

      _ ->
        {:error, :invalid_response}
    end
  end

  defp default_message_icon do
    Enum.random(["female-technologist", "male-technologist"])
  end

  defp build_message(slack, post) do
    Map.merge(slack.send_opts, %{
      icon_emoji:
        case post.icon_emoji do
          nil -> default_message_icon()
          icon when is_binary(icon) -> icon
        end,
      blocks:
        post.blocks
        |> Jason.encode_to_iodata!(pretty: @pretty_json)
    })
  end

  def cleanup_chat_message(%__MODULE__{send_opts: opts}, %{channel: channel, ts: ts}) do
    case Slack.Web.Chat.delete(channel, ts, opts) do
      %{"ok" => true} ->
        :ok

      %{"ok" => false, "error" => "message_not_found"} ->
        :ok

      %{"ok" => false} = resp ->
        {:error, "slack returned unsuccessful response: #{inspect(resp)}"}

      resp ->
        {:error, "slack returned unknown response: #{inspect(resp)}"}
    end
  end
end

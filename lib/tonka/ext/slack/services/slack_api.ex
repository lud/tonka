defmodule Tonka.Ext.Slack.Services.SlackAPI do
  alias Tonka.Ext.Slack.Data.Post
  require Logger
  use TODO
  # use Tonka.Core.Service
  alias Tonka.Core.Service

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
    |> Service.use_service(:credentials, Tonka.Services.Credentials)
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

    cast_result(post_result, channel, message.blocks)
  end

  defp cast_result(result, channel, blocks) do
    case result do
      %{"ok" => true, "channel" => channel, "ts" => _ts} ->
        {:ok, "Slack: Successfully posted to #{channel}"}

      %{"ok" => false, "error" => "channel_not_found"} ->
        {:error, {__MODULE__, {:channel_not_found, channel}}}

      %{"ok" => false, "error" => reason}
      when reason in ["invalid_blocks_format", "invalid_blocks"] ->
        Logger.debug("""

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
    Enum.random(["male-technologist", "female-technologist"])
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
end

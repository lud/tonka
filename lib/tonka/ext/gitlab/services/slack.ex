defmodule Tonka.Ext.Slack.Services.SlackAPI do
  use Tonka.Core.Service
  use TODO
  alias Tonka.Ext.Slack.Data.Post

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

  @spec send_chat_message(%__MODULE__{}, %Post{}, channel :: binary) ::
          {:ok, cleanup_data :: term} | {:error, term}

  def send_chat_message(%__MODULE__{} = slack, %Post{} = post, channel) do
    slack_opts =
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

    Slack.Web.Chat.post_message(channel, post.title, slack_opts)
    |> case do
      %{"ok" => true, "channel" => channel, "ts" => ts} ->
        {:ok, "Slack: Successfully posted to #{channel}"}

      %{"ok" => false, "error" => "channel_not_found"} ->
        {:error, {__MODULE__, {:channel_not_found, channel}}}

      %{"ok" => false, "error" => reason}
      when reason in ["invalid_blocks_format", "invalid_blocks"] ->
        if @pretty_json do
          Logger.debug("""

          Invalid blocks JSON:

          #{slack_opts.blocks}
          """)
        end

        {:error, reason}

      %{"error" => reason, "ok" => false} ->
        {:error, reason}

      _ ->
        {:error, :invalid_response}
    end
  end

  defp default_message_icon() do
    Enum.random(["male-technologist", "female-technologist"])
  end
end

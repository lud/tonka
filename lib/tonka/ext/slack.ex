defmodule Tonka.Ext.Slack do
  @behaviour Tonka.Extension

  @impl Tonka.Extension
  def services do
    %{
      "ext.slack.api" => Tonka.Ext.Slack.Services.SlackAPI
    }
  end

  @impl Tonka.Extension
  def actions do
    %{
      "ext.slack.publisher" => Tonka.Ext.Slack.Actions.SlackPublisher
    }
  end
end

defmodule Tonka.Ext.Slack.Data.Post do
  @enforce_keys [:title, :blocks]
  defstruct title: nil, icon_emoji: nil, blocks: nil

  @spec new(title :: binary, blocks :: list, Keyword.t()) :: %__MODULE__{}
  def new(title, blocks, opts \\ [])
      when is_binary(title) and is_list(blocks) do
    %__MODULE__{title: title, blocks: blocks, icon_emoji: opts[:icon_emoji]}
  end
end

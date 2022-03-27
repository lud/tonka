# -- Booklet content blocks (nested modules) --------------------------------

defmodule Tonka.Core.Booklet.Blocks do
  alias Tonka.Core.Booklet.Block

  defmodule Header do
    use Block

    prop text when is_binary(text), required: true
    prop level when is_integer(level) and level > 0, default: 1
  end

  defmodule Section do
    use Block
    alias Tonka.Core.Booklet.Blocks.RichText

    prop header
    prop content, required: true
    prop footer

    def validate_prop(:header, text) when is_binary(text) do
      {:ok, text}
    end

    def validate_prop(name, nil) when name in [:header, :footer] do
      {:ok, nil}
    end

    def validate_prop(name, data) when name in [:header, :content, :footer] do
      RichText.validate_prop(:data, data)
    end
  end

  defmodule PlainText do
    use Block

    prop text when is_binary(text)
  end

  defmodule Mrkdwn do
    @moduledoc """
    The mrkdwn data type is made to support Slack at the config level.

    Slack uses its own markdown-like syntax, with a lot of incompatibilities
    from regular Markdown. As we want to provide simple configuration
    capabilities by inserting slack message content right in the configuration,
    we need to pass this content along without transformations, but also not as
    "plaintext".
    """
    use Block

    prop mrkdwn when is_binary(mrkdwn)
  end

  defmodule RichText do
    use Block

    @format_tags ~w(strong em strike)a

    prop data when not is_atom(data), required: true

    def validate_prop(:data, data) do
      validate_data(data)
    end

    def validate_data(raw) when is_binary(raw) do
      {:ok, raw}
    end

    def validate_data(list) when is_list(list) do
      list
      |> Enum.reject(&Kernel.match?({:ok, _}, validate_data(&1)))
      |> case do
        [] ->
          {:ok, list}

        invalid ->
          {:error, "the list of elements contains invalid elements: #{inspect(invalid)}"}
      end
    end

    def validate_data({tag, sub}) when tag in @format_tags do
      validate_data(sub)
    end

    def validate_data({:datetime, %DateTime{}} = data) do
      {:ok, data}
    end

    def validate_data(%DateTime{} = data) do
      {:ok, data}
    end

    def validate_data({:link, url, sub}) do
      if is_binary(url),
        do: validate_data(sub),
        else: {:error, "the url for :link must be a string"}
    end

    def validate_data({:ul, list}) do
      if is_list(list),
        do: validate_data(list),
        else: {:error, ":ul must contain a list of elements"}
    end
  end
end

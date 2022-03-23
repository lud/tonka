defmodule Tonka.Core.Booklet do
  alias __MODULE__
  alias Tonka.Core.Booklet.Block

  defstruct blocks: [], title: "Booklet Title", assigns: %{}

  @type t :: %Booklet{}

  @spec from_blocks(list) :: {:ok, %Booklet{}} | {:error, term}
  def from_blocks(blocks) when is_list(blocks) do
    blocks
    |> splat_list()
    |> Block.cast_blocks()
    |> case do
      {:ok, blocks} -> {:ok, %Booklet{blocks: blocks}}
      {:error, _} = err -> err
    end
  end

  def from_blocks!(blocks) do
    case from_blocks(blocks) do
      {:ok, blocks} ->
        blocks

      {:error, {:unknown_prop, block, k, _v}} ->
        raise ArgumentError,
          message: "unknown property #{inspect(k)} for block #{block}"

      {:error, reason} ->
        raise "could not build block: #{inspect(reason)}"
    end
  end

  @doc """
  Flattens the list and removes all `nil` entries from the result.
  This function is automatically used when calling `from_blocks/1`.

  Useful to build a list of blocks with conditional blocks:
    - nil can be returned when building an unnecessary block
    - building blocks from nested structures can return an nested list as it
      will be flattened.
  """
  def splat_list(list) when is_list(list) do
    list
    |> :lists.flatten()
    |> Enum.reject(fn
      nil -> true
      _ -> false
    end)
  end

  def assign(%Booklet{assigns: current} = bl, assigns)
      when is_list(assigns)
      when is_map(assigns) do
    %Booklet{bl | assigns: Enum.into(current, assigns)}
  end

  # -- Booklet content blocks (nested modules) --------------------------------

  defmodule Block.Header do
    use Block

    prop(text when is_binary(text), required: true)
  end

  defmodule Block.Section do
    use Block

    prop(header)
    prop(content, required: true)
    prop(footer)

    def validate_prop(:header, text) when is_binary(text) when is_tuple(text) do
      {:ok, text}
    end

    def validate_prop(name, nil) when name in [:header, :footer] do
      {:ok, nil}
    end

    def validate_prop(name, data) when name in [:header, :content, :footer] do
      Tonka.Core.Booklet.Block.RichText.validate_prop(:data, data)
    end
  end

  defmodule Block.PlainText do
    use Block

    prop(text when is_binary(text))
  end

  defmodule Block.Mrkdwn do
    @moduledoc """
    The mrkdwn data type is made to support Slack at the config level.

    Slack uses its own markdown-like syntax, with a lot of incompatibilities
    from regular Markdown. As we want to provide simple configuration
    capabilities by inserting slack message content right in the configuration,
    we need to pass this content along without transformations, but also not as
    "plaintext".
    """
    use Block

    prop(mrkdwn when is_binary(mrkdwn))
  end

  defmodule Block.RichText do
    use Block

    @format_tags ~w(strong em strike)a

    prop(data when not is_atom(data), required: true)

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

defmodule Tonka.Ext.Slack.BlockKit.Compiler do
  defmacro defblock(type) when is_atom(type) do
    _defblock(type, type, {:%{}, [], []})
  end

  defmacro defblock(fun_name, type) when is_atom(fun_name) and is_atom(type) do
    _defblock(fun_name, type, {:%{}, [], []})
  end

  defmacro defblock(type, {:%{}, _, _} = defaults) when is_atom(type) do
    _defblock(type, type, defaults)
  end

  @doc """

  Creates a function named `fun_name` that returns a block of type `type`.
  The function will merge the passed properties with the `defaults`.
  """
  defmacro defblock(fun_name, type, {:%{}, _, _} = defaults)
           when is_atom(fun_name) and is_atom(type) do
    _defblock(fun_name, type, defaults)
  end

  defp _defblock(fun_name, type, defaults) do
    type_str = Atom.to_string(type)

    quote location: :keep do
      def unquote(fun_name)(node) when is_list(node) do
        build_node(unquote(type_str), node, unquote(defaults))
      end

      def unquote(fun_name)(node) when is_map(node) do
        build_node(unquote(type_str), Map.to_list(node), unquote(defaults))
      end
    end
  end

  defmacro __using__(_) do
    quote location: :keep do
      import __MODULE__.Compiler, only: :macros

      @spec build_node(binary, props :: list({atom, any}), defaults :: map) ::
              map

      defp build_node(type, node, defaults) do
        node =
          [{:type, type} | node]
          |> cast_props
          |> Map.new()

        Map.merge(defaults, node)
      end

      defp cast_props(_) do
        raise "An implementation of cast_props/1 is required in #{__MODULE__}"
      end

      def plain_text(_) do
        raise "An implementation of plain_text/1 is required in #{__MODULE__}"
      end

      defoverridable build_node: 3, cast_props: 1, plain_text: 1
    end
  end
end

defmodule Tonka.Ext.Slack.BlockKit do
  use TODO
  use __MODULE__.Compiler

  defp cast_props([nil | rest]), do: cast_props(rest)

  defp cast_props([{:text, text} | rest]) when is_binary(text),
    do: [{:text, plain_text(text)} | cast_props(rest)]

  defp cast_props([{:__rawtext__, text} | rest]) when is_binary(text),
    do: [{:text, text} | cast_props(rest)]

  defp cast_props([v | rest]),
    do: [v | cast_props(rest)]

  defp cast_props([]),
    do: []

  def plain_text(text, emoji? \\ true) do
    %{type: "plain_text", emoji: emoji?, text: text}
  end

  def link(url) do
    "<#{url}>"
  end

  @todo "Format BlockKit link when url is nil? + gettext"
  def link(url, title) do
    title =
      title
      |> to_string
      |> String.replace("<", "‹")
      |> String.replace(">", "›")

    "<#{url}|#{title}>"
  end

  def to_json(term) do
    term
  end

  def rm_nils([nil | rest]), do: rm_nils(rest)
  def rm_nils([v | rest]), do: [v | rm_nils(rest)]
  def rm_nils([]), do: []

  # just like :lists.flatten but ignoring nil values
  def block_list([]),
    do: []

  def block_list(list) when is_list(list),
    do: block_list(list, [])

  defp block_list([h | t], tail) when is_list(h),
    do: block_list(h, block_list(t, tail))

  defp block_list([nil | t], tail),
    do: block_list(t, tail)

  defp block_list([text | t], tail) when is_binary(text) do
    [plain_text(text) | block_list(t, tail)]
  end

  defp block_list([h | t], tail),
    do: [h | block_list(t, tail)]

  defp block_list([], tail),
    do: tail

  defblock(:_header, :header)

  def header(text) when is_binary(text) do
    _header(text: text)
  end

  def header(opts) when is_list(opts) do
    _header(opts)
  end

  defblock(:_context, :context)

  def context(elements) when is_list(elements) do
    _context(elements: block_list(elements))
  end

  defblock(:_mrkdwn, :mrkdwn)

  def mrkdwn(text) when is_binary(text) do
    _mrkdwn(__rawtext__: text)
  end

  @todo "Maybe remove default alt_text to force accessibility"
  defblock(:_image, :image, %{alt_text: "An image"})

  def image(url, alt_text) do
    _image(image_url: url, alt_text: alt_text)
  end

  defblock(:divider)

  def divider do
    divider([])
  end

  defblock(:_section, :section)

  def section(text) when is_binary(text) do
    _section(text: text)
  end

  def section(%{type: "plain_text"} = text) do
    _section(text: text)
  end

  def section(%{type: "mrkdwn"} = text) do
    _section(text: text)
  end

  def section(opts) when is_list(opts) do
    _section(opts)
  end

  defblock(:button)

  def button(text, opts) when is_binary(text) do
    button([{:text, text} | opts])
  end
end

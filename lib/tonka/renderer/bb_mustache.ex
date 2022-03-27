defmodule Tonka.Renderer.BBMustache do
  def render(template, params) do
    {:ok, :bbmustache.render(template, params, key_type: :binary, raise_on_context_miss: true)}
  rescue
    e -> {:error, e}
  end

  @doc """
  Accepts a data tree and apply the render function for all encountered binaries
  in the tree.
  """
  def render_tree(tree, params)

  def render_tree(map, params) when is_map(map) do
    Enum.into(map, %{}, fn {k, v} -> {k, render_tree(v, params)} end)
  end

  def render_tree(list, params) when is_list(list) do
    Enum.map(list, &render_tree(&1, params))
  end

  def render_tree({k, v}, params) when is_binary(v) do
    {k, render(v, params)}
  end

  # def render_tree({k, k2, v}, params) when is_binary(v) do
  #   {k, k2, render(v, params)}
  # end

  def render_tree(string, params) when is_binary(string) do
    render(string, params)
  end

  def render_tree(other, _) do
    other
  end
end

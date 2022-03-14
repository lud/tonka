defmodule Tonka.Core.Container.Params do
  @behaviour Tonka.Core.Container.Type

  def expand_type, do: {:type, :term}
end

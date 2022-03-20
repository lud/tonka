defmodule Tonka.Test.Fixtures.OpNoInputs do
  alias Tonka.Core.Action
  alias Tonka.Core.Container
  use Action

  # def __mix_recompile__?, do: true

  @impl true
  def call(_, _, _), do: {:ok, nil}
end

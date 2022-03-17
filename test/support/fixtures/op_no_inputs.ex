defmodule Tonka.Test.Fixtures.OpNoInputs do
  alias Tonka.Core.Operation
  alias Tonka.Core.Container
  use Operation

  # def __mix_recompile__?, do: true

  @impl true
  def output_spec, do: %Container.ReturnSpec{type: nil}

  @impl true
  def call(_, _, _), do: {:ok, nil}
end

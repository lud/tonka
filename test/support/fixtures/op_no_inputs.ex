defmodule Tonka.Test.Fixtures.OpNoInputs do
  alias Tonka.Core.Operation
  use Operation

  # def __mix_recompile__?, do: true

  @impl true
  def output_spec, do: %Operation.OutputSpec{type: nil}

  @impl true
  def call(_, _, _), do: {:ok, nil}
end

defmodule Tonka.Test.Fixtures.OpNoInputs do
  alias Tonka.Core.Operation
  use Operation

  def __mix_recompile__?, do: true

  def output_spec, do: raise("should not be called")
end

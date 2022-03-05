defmodule Tonka.Test.Fixtures.OpOneInexistingInput do
  alias Tonka.Core.Operation
  use Operation

  def __mix_recompile__?, do: true

  input myvar in A.B.C

  output(X.Y.Z)
end

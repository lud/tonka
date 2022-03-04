defmodule Tonka.Core.InputCaster do
  alias Tonka.Core.Operation

  @moduledoc """
  This behaviour describes a special kind of `Tonka.Core.Operation` that must
  accept a single untyped term as its input and tries to cast it to the type
  described by the `c:output_spec/0` callback.

  It is used as the input acceptor in a `Tonka.Core.Grid`, and its output value
  will be passed as input to all grid operations that have `:incast` in their
  `:inputs` mapping.
  """

  @callback output_spec(Operation.params()) :: Operation.OutputSpec.t()
  @callback call(term, Operation.params(), injects :: map) :: Operation.op_out()
end

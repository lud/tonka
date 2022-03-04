defmodule Tonka.Core.Operation.OutputSpec do
  @moduledoc """
  Defines the specification of the ouput value of a `Tonka.Core.Operation`.
  """

  @enforce_keys [:type]
  defstruct @enforce_keys

  @type t :: %__MODULE__{type: Tonka.Core.Container.typespec()}
end

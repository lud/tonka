defmodule Tonka.Core.Operation.OutputSpec do
  @enforce_keys [:type]
  defstruct @enforce_keys

  @type t :: %__MODULE__{type: Tonka.Core.Container.typespec()}
end

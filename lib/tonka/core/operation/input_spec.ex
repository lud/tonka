defmodule Tonka.Core.Operation.InputSpec do
  @enforce_keys [:key, :type]
  defstruct @enforce_keys

  @type t :: %__MODULE__{key: :atom, type: Tonka.Core.Container.typespec()}
end

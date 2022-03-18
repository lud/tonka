defmodule Tonka.Core.Operation.InputSpec do
  @moduledoc """
  Defines the specification of one input argument of a `Tonka.Core.Operation`.
  """

  @enforce_keys [:key, :type, :cast_static]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          key: atom,
          type: Tonka.Core.Container.typespec(),
          cast_static: {module, atom, list}
        }
end

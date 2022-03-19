defmodule Tonka.Core.Container.ReturnSpec do
  @moduledoc """
  Defines the specification of the ouput value of a `Tonka.Core.Action`.
  """

  @enforce_keys [:type]
  defstruct @enforce_keys

  @type t :: %__MODULE__{type: Tonka.Core.Container.typespec()}
end

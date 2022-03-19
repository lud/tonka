defmodule Tonka.Core.Container.InjectSpec do
  @moduledoc """
  Defines the specification of one input argument of a `Tonka.Core.Action`.
  """

  @enforce_keys [:key, :type]
  defstruct @enforce_keys

  @type t :: %__MODULE__{key: atom, type: Tonka.Core.Container.typespec()}
end

defmodule Tonka.Core.Operation do
  defmodule InputSpec do
    @enforce_keys [:key, :type]
    defstruct @enforce_keys

    @type t :: %__MODULE__{key: :atom, type: Tonka.Core.Container.typespec()}
  end

  defmodule OutputSpec do
    @enforce_keys [:type]
    defstruct @enforce_keys

    @type t :: %__MODULE__{type: Tonka.Core.Container.typespec()}
  end

  @type params :: map
  @type op_in :: map
  @type op_out :: {:ok, term} | {:error, term} | {:async, Task.t()}

  @callback input_specs() :: [InputSpec.t()]
  @callback output_spec() :: OutputSpec.t()

  @callback call(op_in, injects :: map) :: op_out
end

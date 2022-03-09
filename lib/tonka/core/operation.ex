defmodule Tonka.Core.Operation do
  @moduledoc """
  Behaviour defining the callbacks of modules and datatypes used as operations
  in a `Tonka.Core.Grid`.
  """

  alias Tonka.Core.Container.InjectSpec
  alias Tonka.Core.Container.ReturnSpec

  @type params :: map
  @type op_in :: map
  @type op_out :: op_out(term)
  @type op_out(output) :: {:ok, output} | {:error, term} | {:async, Task.t()}

  @callback input_specs() :: [InjectSpec.t()]
  @callback output_spec() :: ReturnSpec.t()

  @callback call(op_in, params, injects :: map) :: op_out

  defmacro __using__(_) do
    quote location: :keep do
      import Tonka.Core.Operation.OperationMacros
      Tonka.Core.Operation.OperationMacros.init_module()
    end
  end
end

defmodule Tonka.Core.Operation do
  @moduledoc """
  Behaviour defining the callbacks of modules and datatypes used as operations
  in a `Tonka.Core.Grid`.
  """

  @type params :: map
  @type op_in :: map
  @type op_out :: {:ok, term} | {:error, term} | {:async, Task.t()}

  @callback input_specs() :: [InputSpec.t()]
  @callback output_spec() :: OutputSpec.t()

  @callback call(op_in, injects :: map) :: op_out

  defmacro __using__(_) do
    quote do
      alias unquote(__MODULE__), as: Operation
      @behaviour Operation
      @before_compile Operation
      import Operation, only: :macros
    end
  end

  defmacro input(definition) do
    definition |> IO.inspect(label: "definition")
    nil
  end

  defmacro __before_compile__(env) do
    nil
  end
end

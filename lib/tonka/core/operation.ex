defmodule Tonka.Core.Operation do
  @type op_in :: map
  @type op_out :: {:ok, term} | {:error, term} | {:async, Task.t()}

  @callback call(op_in, injects :: map) :: op_out
end

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

      Module.register_attribute(__MODULE__, :tonka_input_specs, accumulate: true)
    end
  end

  defmacro input(definition) do
    escaped = normalize_input(definition)

    quote location: :keep do
      @tonka_input_specs unquote(escaped)
    end
    |> tap(&IO.puts(Macro.to_string(&1)))
  end

  defp normalize_input({:in, _, [var, type]}) do
    {normalize_vardef(var), normalize_type(type)}
  end

  defp normalize_vardef({varname, meta, nil}) when is_atom(varname) when is_list(meta) do
    varname
  end

  defp normalize_type({:__aliases__, _, _} = mod_type) do
    mod_type
  end

  defmacro __before_compile__(_env) do
    [
      def_inputs()
    ]
  end

  defp def_inputs do
    quote do
      alias Tonka.Core.Operation
      @spec input_specs() :: [Operation.InputSpec.t()]

      @__built_input_specs for {varname, type} <- @tonka_input_specs,
                               do: %Operation.InputSpec{key: varname, type: type}

      def input_specs() do
        @__built_input_specs
      end
    end
  end
end

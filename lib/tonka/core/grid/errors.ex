defmodule Tonka.Core.Grid.InvalidInputTypeError do
  defexception [:op_key, :input_key, :expected_type, :provided_type]

  def message(%{
        op_key: op_key,
        input_key: input_key,
        expected_type: input_type,
        provided_type: provided_type
      }) do
    "invalid input type for operation #{inspect(op_key)} at input #{inspect(input_key)}," <>
      " expected: #{inspect(input_type)} but got #{inspect(provided_type)}"
  end
end

defmodule Tonka.Core.Grid.NoInputCasterError do
  defexception []

  def message(_), do: "the grid has no input caster defined"
end

defmodule Tonka.Core.Grid.UnmappedInputError do
  defexception [:op_key, :input_key]

  def message(%{op_key: op_key, input_key: input_key}) do
    "unmapped input #{inspect(input_key)} for operation #{inspect(op_key)}"
  end
end

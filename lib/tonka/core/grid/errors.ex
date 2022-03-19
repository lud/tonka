defmodule Tonka.Core.Grid.InvalidInputTypeError do
  defexception [:action_key, :input_key, :expected_type, :provided_type]

  def message(%{
        action_key: action_key,
        input_key: input_key,
        expected_type: input_type,
        provided_type: provided_type
      }) do
    "invalid input type for action #{inspect(action_key)} at input #{inspect(input_key)}," <>
      " expected: #{inspect(input_type)} but got #{inspect(provided_type)}"
  end
end

defmodule Tonka.Core.Grid.NoInputCasterError do
  defexception []

  def message(_), do: "the type grid has no input caster defined"
end

defmodule Tonka.Core.Grid.UndefinedOriginActionError do
  defexception [:action_key, :origin_key]

  def message(%{action_key: act, origin_key: ori}) do
    "the grid has no '#{ori}' action but this origin is defined in action '#{act}'"
  end
end

defmodule Tonka.Core.Grid.UnmappedInputError do
  defexception [:action_key, :input_key]

  def message(%{action_key: action_key, input_key: input_key}) do
    "unmapped input #{inspect(input_key)} for action '#{action_key}'"
  end
end

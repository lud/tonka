defmodule Tonka.Core.Grid.InvalidInputTypeError do
  defexception [:action_key, :input_key, :expected_type, :provided_type]

  def message(%{
        action_key: action_key,
        input_key: input_key,
        expected_type: input_type,
        provided_type: provided_type
      }) do
    "invalid input type for action '#{action_key}' at input #{inspect(input_key)}," <>
      " expected: #{inspect(input_type)} but got #{inspect(provided_type)}"
  end
end

defmodule Tonka.Core.Grid.NoInputCasterError do
  defexception [:origin, :action_key, :input_key, :input_type]

  def message(%{origin: ori, action_key: act, input_key: ik, input_type: type}),
    do:
      "invalid input origin #{inspect(ori)} for action #{act} at input #{inspect(ik)}," <>
        " type #{inspect(type)} has no caster defined"
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

defmodule Tonka.Core.Grid.UnavailableServiceError do
  defexception [:action_key, :inject_key]

  def message(%{action_key: action_key, inject_key: inject_key}) do
    "service #{inspect(inject_key)} was not found when initializing action '#{action_key}'"
  end
end

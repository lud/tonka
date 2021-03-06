alias Tonka.Core.Grid

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
      "unsupported input origin #{inspect(ori)} for action #{act} at input #{inspect(ik)}," <>
        " type #{inspect(type)} has no caster defined"
end

defmodule Tonka.Core.Grid.CastError do
  defexception [:action_key, :input_key, :input_type, :reason]

  def message(%{action_key: act, input_key: ik, input_type: type, reason: reason}) do
    "error when casting input #{inspect(ik)} of type #{inspect(type)} for action #{act}: " <>
      inspect(reason)
  end
end

defmodule Tonka.Core.Grid.ActionFailureError do
  defexception [:action_key, :reason]

  def message(%{action_key: act, reason: reason}),
    do: "action #{act} failed with reason: #{Grid.format_error(reason)}"
end

defmodule Tonka.Core.Grid.UndefinedOriginActionError do
  defexception [:action_key, :origin_action_key, :input_key]

  def message(%{action_key: act, input_key: ik, origin_action_key: ori}) do
    "action '#{act}' defines input #{inspect(ik)} to use the result of an unknown action '#{ori}'"
  end
end

defmodule Tonka.Core.Grid.UnmappedInputError do
  defexception [:action_key, :input_key]

  def message(%{action_key: action_key, input_key: input_key}) do
    "unmapped input #{inspect(input_key)} for action '#{action_key}'"
  end
end

defmodule Tonka.Core.Grid.UnavailableServiceError do
  defexception [:action_key, :inject_key, :container_error]

  def message(%{action_key: action_key, inject_key: inject_key, container_error: ce}) do
    "service #{inspect(inject_key)} was not found when initializing action '#{action_key}': #{Exception.message(ce)}"
  end
end

defmodule Tonka.Core.Grid do
  @moduledoc """
  A grid is an execution context for multiple actions.
  """

  use Tonka.GLogger

  alias Tonka.Core.Grid.{
    InvalidInputTypeError,
    NoInputCasterError,
    UnmappedInputError,
    UndefinedOriginActionError
  }

  alias Tonka.Core.Action
  alias __MODULE__

  @type input_caster_opt :: {:params, map}
  @type input_caster_opts :: [input_caster_opt]
  @type outputs :: %{optional(binary | :incast) => term}
  @type action :: Action.t()
  @type actions :: %{optional(binary) => action}
  @type statuses :: %{optional(binary) => :uninitialized | :called}

  @enforce_keys [:actions, :outputs, :statuses, :input_caster]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          actions: [Action.t()],
          outputs: outputs,
          statuses: statuses
        }

  # ---------------------------------------------------------------------------
  #  Grid Building
  # ---------------------------------------------------------------------------

  def new do
    %Grid{actions: %{}, outputs: %{}, statuses: %{}, input_caster: nil}
  end

  @addop_schema NimbleOptions.new!(
                  params: [
                    doc: """
                    The raw data structure that will be passed to the action
                    module as params. Defaults to an empty map
                    """,
                    default: %{}
                  ]
                )

  def add_action(grid, key, module, opts \\ [])

  def add_action(%Grid{actions: actions}, key, _module, _opts)
      when is_map_key(actions, key) do
    raise ArgumentError, "an action with the key #{inspect(key)} is already defined"
  end

  def add_action(%Grid{actions: actions} = grid, key, module, opts)
      when is_binary(key) and is_atom(module) do
    opts = NimbleOptions.validate!(opts, @addop_schema)
    action = Action.new(module, params: opts[:params])
    actions = Map.put(actions, key, action)
    %Grid{grid | actions: actions}
  end

  # ---------------------------------------------------------------------------
  #  Grid Validation
  # ---------------------------------------------------------------------------

  def validate(%Grid{} = grid) do
    with :ok <- validate_all_inputs(grid) do
      {:ok, grid}
    end
  end

  def validate!(grid) do
    case validate(grid) do
      {:ok, grid} -> grid
      {:error, {_tag, [%_{} = err | _]}} -> raise err
    end
  end

  # Validates that all mapped action inputs are mapped, and are mapped to an
  # output that provides the same type.  The inputs mapped to the :incast (the
  # grid input) are validated by ensuring that the type module of the input has
  # a cast_input/1 callback.
  defp validate_all_inputs(%{actions: actions}) do
    Enum.reduce(actions, _invalids = [], fn action, invalids ->
      validated = validate_inputs(action, actions)

      case validated do
        :ok -> invalids
        {:error, more_invalids} -> more_invalids ++ invalids
      end
    end)
    |> case do
      [] -> :ok
      invalids -> {:error, {:invalid_inputs, invalids}}
    end
  end

  # validates the input for one action given all other actions outputs
  defp validate_inputs(%{config_called: true} = action, actions) do
    {act_key, %{input_mapping: mapping, config: %{inputs: input_specs}}} = action

    Enum.filter(input_specs, fn %{key: input_key, type: input_type} = input_spec ->
      with {:ok, output_type} <- fetch_mapped_input_type(mapping, input_key, act_key, actions),
           :ok <- validate_type_compat(input_type, output_type) do
        :ok
      else
        :x -> {:error, :x}
      end
    end)
    |> Enum.filter(fn
      :ok -> false
      {:error, _} -> true
    end)
    |> case do
      [] -> :ok
      errors -> {:error, Keyword.values(errors)}
    end
  end

  defp fetch_mapped_input_type(mapping, input_key, act_key, actions) do
    case mapping[input_key] do
      %{origin: :action, action: origin_action_key} ->
        fetch_origin_action_output_type(actions, origin_action_key)

      nil ->
        {:error, :unmapped}
    end
  end

  defp fetch_origin_action_output_type(actions, origin_action_key) do
    case Map.fetch(actions, origin_action_key) do
      {:ok, %{module: module}} -> {:ok, module.return_type()}
      :error -> {:error, {:no_such_action, origin_action_key}}
    end
  end

  defp validate_type_compat(input_type, output_type) do
    if input_type == output_type do
      :ok
    else
      {:error, {:incompatible_types, input_type, output_type}}
    end
  end

  # ---------------------------------------------------------------------------
  #  Grid Running
  # ---------------------------------------------------------------------------

  def run(%Grid{actions: actions} = grid, input) do
    outputs = %{input: input}
    statuses = start_statuses(grid.actions)
    grid = %Grid{grid | outputs: outputs, statuses: statuses}

    GLogger.debug("running a grid")

    with {:ok, grid} <- precast_all(grid),
         {:ok, grid} <- validate(grid) do
      run(grid)
    else
      {:error, _} = err -> err
    end
  end

  # defp call_input(%{input_caster: {incast, caster_params}, outputs: outputs} = grid, input) do
  #   output = InputCaster.call(incast, input, caster_params, %{})

  #   %Grid{grid | outputs: Map.put(outputs, :incast, output)}
  # end

  defp start_statuses(actions) do
    Enum.into(actions, %{}, fn {key, _} -> {key, :uninitialized} end)
  end

  @spec reduce_actions_ok(actions, ({binary, action} -> {:ok, action} | {:error, term})) ::
          {:ok, actions} | {:error, term}
  defp reduce_actions_ok(enum, callback) do
    Enum.reduce_while(enum, [], fn item, acc ->
      case callback.(item) do
        {:ok, result} -> {:cont, [result | acc]}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:error, _} = err -> err
      list -> {:ok, Map.new(list)}
    end
  end

  def precast_all(%Grid{actions: actions} = grid) do
    case reduce_actions_ok(actions, &precast_action/1) do
      {:ok, actions} -> {:ok, %Grid{grid | actions: actions}}
      {:error, _} = err -> err
    end
  end

  defp precast_action({k, action}) do
    GLogger.debug(~s(precasting params of action "#{k}"))

    case Action.precast_params(action) do
      {:ok, action} -> {:ok, {k, action}}
      {:error, _} = err -> err
    end
  end

  defp run(grid) do
    runnable = find_runnable(grid)

    case runnable do
      {:ok, key} -> grid |> call_action(key) |> run()
      :none -> {:done, grid}
    end
  end

  defp call_action(%{actions: actions, outputs: outputs, statuses: statuses} = grid, key) do
    # inputs = build_input(grid, key)
    inputs = []

    %{module: module, params: params} = Map.fetch!(actions, key)

    output = module.call(inputs, params, %{})

    %Grid{
      grid
      | statuses: Map.put(statuses, key, :called),
        outputs: Map.put(outputs, key, output)
    }
  end

  defp find_runnable(%Grid{actions: actions, outputs: outputs, statuses: statuses}) do
    uninit_keys = for {key, :uninitialized} <- statuses, do: key
    uninit_actions = Map.take(actions, uninit_keys)

    case uninit_actions do
      [] ->
        :done

      _ ->
        with_inputs_ready = Enum.filter(uninit_actions, &all_inputs_ready?(&1, outputs))

        case with_inputs_ready do
          [{key, _} | _] -> {:ok, key}
          [] -> :noavail
        end
    end
  end

  defp all_inputs_ready?(%{config_called: true, config: config} = _action, outputs) do
    inputs_keys = Enum.map(config.inputs, & &1.key)
    Enum.all?(inputs_keys, &Map.has_key?(outputs, &1))
  end

  # defp build_input(%{outputs: outputs, actions: actions}, key) do
  #   %{inputs: inputs} = Map.fetch!(actions, key)
  #   Enum.into(inputs, %{}, fn {key, source} -> {key, Map.fetch!(outputs, source)} end)
  # end
end

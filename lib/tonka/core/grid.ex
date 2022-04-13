defmodule Tonka.Core.Grid do
  alias __MODULE__
  alias Tonka.Core.Action
  alias Tonka.Core.Container
  alias Tonka.Core.Container.InjectSpec
  alias Tonka.Core.Grid.ActionFailureError
  alias Tonka.Core.Grid.CastError
  alias Tonka.Core.Grid.InvalidInputTypeError
  alias Tonka.Core.Grid.NoInputCasterError
  alias Tonka.Core.Grid.UnavailableServiceError
  alias Tonka.Core.Grid.UndefinedOriginActionError
  alias Tonka.Core.Grid.UnmappedInputError
  use TODO
  use Tonka.Project.ProjectLogger, as: Logger

  @moduledoc """
  A grid is an execution context for multiple actions.
  """

  @type outputs :: %{optional(binary | :incast) => term}
  @type action :: Action.t()
  @type actions :: %{optional(binary) => action}
  @type statuses :: %{optional(binary) => :uninitialized | :called}

  @enforce_keys [:actions, :outputs, :statuses]
  defstruct @enforce_keys

  @todo "typing of struct"
  @type t :: %__MODULE__{}

  # ---------------------------------------------------------------------------
  #  Grid Building
  # ---------------------------------------------------------------------------

  def new do
    %Grid{actions: %{}, outputs: %{}, statuses: %{}}
  end

  @add_schema NimbleOptions.new!(
                params: [
                  doc: """
                  The raw data structure that will be passed to the action
                  module as params.
                  """,
                  default: %{}
                ],
                inputs: [
                  doc: """
                  Defines the mapping of each input. A map with all action
                  input keys is expected, with the values being a sub-map with
                  an `:origin` field set to `:static`, `:action` or
                  `:grid_input`.
                      - If `:static`, the sub-map must also have a `:static` key
                        containing the input data.
                      - If `:action`, the sub-map must also have an `:action`
                        key with the name of another action of the grid.
                      - If `:grid_input`, the grid initial input will be passed
                        to that action input.
                  """,
                  type: {:custom, __MODULE__, :validate_input_mapping, []},
                  default: %{}
                ]
              )

  @doc """
  Adds an action to the grid.

  ### Options

  #{NimbleOptions.docs(@add_schema)}
  """

  def add_action(grid, key, module, opts \\ [])

  def add_action(%Grid{actions: actions} = grid, key, module, opts)
      when is_binary(key) and is_atom(module) and is_list(opts) do
    if is_map_key(actions, key) do
      raise ArgumentError, "an action with the key #{inspect(key)} is already defined"
    end

    opts = NimbleOptions.validate!(opts, @add_schema)
    action = Action.new(module, params: opts[:params], input_mapping: opts[:inputs])
    actions = Map.put(actions, key, action)
    %Grid{grid | actions: actions}
  end

  def pipe_static(mapping, input_key, data) when is_map(mapping) and is_atom(input_key),
    do: Map.put(mapping, input_key, %{origin: :static, static: data})

  def pipe_action(mapping, input_key, action_key)
      when is_map(mapping) and is_atom(input_key) and is_binary(action_key),
      do: Map.put(mapping, input_key, %{origin: :action, action: action_key})

  def pipe_grid_input(mapping, input_key) when is_map(mapping) and is_atom(input_key),
    do: Map.put(mapping, input_key, %{origin: :grid_input})

  @doc false
  # used for NimbleOptions
  def validate_input_mapping(mapping) when not is_map(mapping) do
    {:error, "invalid input mapping: #{inspect(mapping)}"}
  end

  def validate_input_mapping(mapping) do
    case Ark.Ok.map_ok(mapping, &validate_mapped_input/1) do
      {:ok, _} -> {:ok, mapping}
      {:error, _} = err -> err
    end
  end

  defp validate_mapped_input({k, v}) do
    case {k, v} do
      {k, _} when not is_atom(k) ->
        {:error, "expected mapped input key to be an atom, got: #{inspect(k)}"}

      {_, %{origin: :action, action: a}} when is_binary(a) ->
        {:ok, {k, v}}

      {_, %{origin: :static, static: _}} ->
        {:ok, {k, v}}

      {_, %{origin: :grid_input}} ->
        {:ok, {k, v}}

      other ->
        {:error, "invalid mapping format: #{inspect(other)}"}
    end
  end

  # ---------------------------------------------------------------------------
  #  Grid Validation
  # ---------------------------------------------------------------------------

  # Validates that all services types required by actions are defined and built
  # in the container..
  defp validate_all_injects(%{actions: actions}, container) do
    Logger.info("validating services for all actions")

    Enum.reduce(actions, _invalids = [], fn action, invalids ->
      validated = validate_injects(action, container)

      case validated do
        :ok -> invalids
        {:error, more_invalids} -> more_invalids ++ invalids
      end
    end)
    |> case do
      [] -> :ok = Logger.info("✓✓ all actions services are valid")
      invalids -> {:error, {:invalid_injects, invalids}}
    end
  end

  defp validate_injects({act_key, %{config_called: true} = action}, container) do
    Logger.debug("validating services for action '#{act_key}'")
    %{config: %{injects: inject_specs}} = action

    inject_specs
    |> Enum.map(fn {_inject_key, inject_spec} ->
      validate_action_inject(inject_spec, act_key, container)
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

  defp validate_action_inject(%{key: inject_key, type: utype}, act_key, container) do
    Container.pull_frozen(container, utype)

    # we will fetch the type to get a meaningful error from the container
    case Container.pull_frozen(container, utype) do
      {:ok, _} -> :ok
      {:error, reason} -> cast_error({:service_resolve, inject_key, reason}, act_key)
    end
  end

  # Validates that all mapped action inputs are mapped, and are mapped to an
  # output that provides the same type.  The inputs mapped to the :incast (the
  # grid input) are validated by ensuring that the type module of the input has
  # a cast_input/1 callback.
  defp validate_all_inputs(%{actions: actions}) do
    Logger.info("validating inputs for all actions")

    Enum.reduce(actions, _invalids = [], fn action, invalids ->
      validated = validate_inputs(action, actions)

      case validated do
        :ok -> invalids
        {:error, more_invalids} -> more_invalids ++ invalids
      end
    end)
    |> case do
      [] -> :ok = Logger.info("✓✓ all actions inputs are valid")
      invalids -> {:error, {:invalid_inputs, invalids}}
    end
  end

  # validates the input for one action given all other actions outputs
  defp validate_inputs({act_key, %{config_called: true} = action}, actions)
       when is_map(actions) do
    Logger.debug("validating inputs for action '#{act_key}'")
    %{input_mapping: mapping, config: %{inputs: input_specs}} = action

    input_specs
    |> Enum.map(fn {_input_key, input_spec} ->
      validate_action_input(input_spec, act_key, mapping, actions)
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

  defp validate_action_input(
         %{key: input_key, type: input_type} = input_spec,
         act_key,
         mapping,
         actions
       ) do
    with {:ok, output_type} <- fetch_mapped_input_type(mapping, input_spec, actions),
         :ok <- validate_type_compat(input_type, output_type, input_key) do
      :ok
    else
      {:error, reason} -> cast_error(reason, act_key)
    end
  end

  @todo "factorize and document {:raw, type} tuples"

  defp fetch_mapped_input_type(mapping, input_spec, actions) do
    %{key: input_key, type: input_type} = input_spec

    case mapping[input_key] do
      %{origin: :action, action: origin_action_key} ->
        fetch_origin_action_output_type(actions, origin_action_key, input_key)

      %{origin: :static, static: _data} ->
        check_castable_input_type(input_type, :static, input_key)

      %{origin: :grid_input} ->
        check_castable_input_type(input_type, :grid_input, input_key)

      nil ->
        {:error, {:unmapped, input_key}}
    end
  end

  defp check_castable_input_type(input_type, origin, input_key) do
    case input_type do
      {:raw, _} ->
        {:ok, input_type}

      caster when is_atom(caster) ->
        if Tonka.Core.Reflection.load_function_exported_nofail?(input_type, :cast_input, 1),
          do: {:ok, input_type},
          else: {:error, {:no_caster, input_key, input_type, origin}}
    end
  end

  defp fetch_origin_action_output_type(actions, origin_action_key, input_key) do
    case Map.fetch(actions, origin_action_key) do
      {:ok, %{module: module}} -> {:ok, module.return_type()}
      :error -> {:error, {:undef_origin_action, input_key, origin_action_key}}
    end
  end

  defp validate_type_compat(input_type, output_type, input_key) do
    if input_type == output_type do
      :ok
    else
      {:error, {:incompatible_type, input_key, input_type, output_type}}
    end
  end

  # ---------------------------------------------------------------------------
  #  Grid Running
  # ---------------------------------------------------------------------------

  @todo "deprecate"
  # @deprecated "pass a container to the grid using run/3"
  def run(%Grid{} = grid, input) do
    container = Container.new() |> Container.freeze()
    run(grid, container, input)
  end

  @spec run(t, Container.t(), input :: term) :: {:ok, success_status, t} | {:error, error_info, t}
        when success_status: :done, error_info: :noavail | term

  def run(%Grid{} = grid, %Container{} = container, input) do
    ensure_container_frozen(container)
    outputs = %{input: input}
    statuses = start_statuses(grid.actions)
    grid = %Grid{grid | outputs: outputs, statuses: statuses}

    Logger.debug("running the grid")

    case prepare_and_validate(grid, container) do
      {:ok, grid} -> run_loop(grid, container)
      {:error, reason} -> {:error, reason, grid}
    end
  end

  @todo "deprecate"
  # @deprecated "pass a container to the grid using prepare_and_validate/2"
  def prepare_and_validate(%Grid{} = grid) do
    container = Container.new() |> Container.freeze()
    prepare_and_validate(grid, container)
  end

  @doc """
  Casts all actions parameters and calls the configuration function for all
  actions, then runs some validation checks on the actions input and output
  types and mappings.
  """

  def prepare_and_validate(%Grid{} = grid, %Container{} = container) do
    ensure_container_frozen(container)

    with {:ok, grid} <- precast_all(grid),
         {:ok, grid} <- preconfigure_all(grid),
         :ok <- validate_all_injects(grid, container),
         :ok <- validate_all_inputs(grid) do
      {:ok, grid}
    end
  end

  defp ensure_container_frozen(container) do
    if not Container.frozen?(container) do
      raise ArgumentError, "expected the passed container to be frozen"
    end

    container
  end

  @spec run_loop(t, Container.t()) :: {:ok, success_status, term} | {:error, error_info, term}
        when success_status: :done, error_info: :noavail | term

  defp run_loop(grid, container) do
    runnable = find_runnable(grid)

    case runnable do
      {:ok, key} ->
        Logger.debug("action '#{key}' is runnable")

        case call_action(grid, key, container) do
          {:ok, new_grid} ->
            Logger.info("✓ action '#{key}' completed successfully")
            run_loop(new_grid, container)

          {:error, reason, failed_grid} ->
            Logger.error(format_error(reason))
            {:error, reason, failed_grid}
        end

      :done ->
        Logger.info("✓✓ all actions have run")
        {:ok, :done, grid}

      :noavail ->
        # This clause cannot actually be called since we verify the inputs
        todo "remove this clause"
        Logger.error("could not find an action to run but some actions were not called")
        {:error, :noavail, grid}
    end
  end

  defp start_statuses(actions) do
    Enum.into(actions, %{}, fn {key, _} -> {key, :uninitialized} end)
  end

  @spec reduce_actions_ok(actions, ({binary, action} -> {:ok, action} | {:error, term})) ::
          {:ok, actions} | {:error, term}
  defp reduce_actions_ok(actions, f) do
    with {:ok, actions} <- Ark.Ok.map_ok(actions, f) do
      {:ok, Map.new(actions)}
    end
  end

  def precast_all(%Grid{actions: actions} = grid) do
    case reduce_actions_ok(actions, &precast_action/1) do
      {:ok, actions} -> {:ok, %Grid{grid | actions: actions}}
      {:error, _} = err -> err
    end
  end

  defp precast_action({k, action}) do
    Logger.debug("casting params for action '#{k}'")

    case Action.precast_params(action) do
      {:ok, action} -> {:ok, {k, action}}
      {:error, _} = err -> err
    end
  end

  def preconfigure_all(%Grid{actions: actions} = grid) do
    case reduce_actions_ok(actions, &preconfigure_action/1) do
      {:ok, actions} -> {:ok, %Grid{grid | actions: actions}}
      {:error, _} = err -> err
    end
  end

  defp preconfigure_action({k, action}) do
    Logger.debug("calling configuration for action '#{k}'")

    case Action.preconfigure(action) do
      {:ok, action} -> {:ok, {k, action}}
      {:error, _} = err -> err
    end
  end

  @spec call_action(t, binary, Container.t()) :: {:ok, t} | {:error, term, t}

  defp call_action(grid, key, container) do
    %{actions: actions, outputs: outputs, statuses: statuses} = grid
    %{config: %{injects: inject_specs}} = action = Map.fetch!(actions, key)

    with {:ok, injects} <- build_injects(container, inject_specs, key),
         {:ok, inputs} <- build_inputs(grid, key),
         {:ok, output} <- do_call_action(action, inputs, injects, key) do
      grid = %Grid{
        grid
        | statuses: Map.put(statuses, key, :called),
          outputs: Map.put(outputs, key, output)
      }

      {:ok, grid}
    else
      # Do not cast error here to preserve stacktraces if we want a process flag
      # to raise on cast_error for debugging.
      # Each step of the `with` pipeline above must cast its errors
      {:error, reason} -> {:error, reason, grid}
    end
  end

  defp do_call_action(action, inputs, injects, key) do
    Logger.debug("calling action '#{key}'")

    case Action.call(action, inputs, injects) do
      {:ok, _} = fine -> fine
      {:error, reason} -> cast_error({:action_failed, key, reason}, key)
    end
  end

  defp find_runnable(%Grid{actions: actions, outputs: outputs, statuses: statuses}) do
    uninit_keys = for {key, :uninitialized} <- statuses, do: key
    uninit_actions = actions |> Map.take(uninit_keys)

    if 0 == map_size(uninit_actions) do
      :done
    else
      uninit_actions
      |> Enum.filter(fn {_, action} -> all_inputs_ready?(action, outputs) end)
      |> case do
        [{key, _} | _] -> {:ok, key}
        [] -> :noavail
      end
    end
  end

  defp build_injects(container, inject_specs, act_key) do
    # this code is kinda the same as in container, but we reimplement it because
    # we want to know which inject key fails.
    Ark.Ok.reduce_ok(
      inject_specs,
      %{},
      fn {key, %InjectSpec{type: utype, key: key}}, map ->
        case Container.pull_frozen(container, utype) do
          {:ok, impl} -> {:ok, Map.put(map, key, impl)}
          {:error, reason} -> cast_error({:service_resolve, key, reason}, act_key)
        end
      end
    )
  end

  defp all_inputs_ready?(%{config_called: true, input_mapping: mapping}, outputs) do
    # This function can only be called if the mapping has been verified, as we
    # will not look into the input specs again but only consider the mapping.

    mapping
    |> Enum.filter(fn {_, %{origin: ori}} -> ori == :action end)
    |> Enum.all?(fn {_, %{action: depended_on_action_key}} ->
      Map.has_key?(outputs, depended_on_action_key)
    end)
  end

  defp build_inputs(%{outputs: outputs, actions: actions}, act_key) do
    Logger.debug("building inputs for action '#{act_key}'")
    action = Map.fetch!(actions, act_key)
    %{input_mapping: mapping, config: %{inputs: input_specs}} = action

    inputs_result = Ark.Ok.map_ok(mapping, &fetch_input(&1, input_specs, outputs))

    case inputs_result do
      {:ok, inputs} -> {:ok, Map.new(inputs)}
      {:error, reason} -> cast_error(reason, act_key)
    end
  end

  defp fetch_input(mapped_input_kv, input_specs, outputs)

  defp fetch_input({input_key, %{origin: :action, action: key}}, _, outputs) do
    {:ok, {input_key, Map.fetch!(outputs, key)}}
  end

  defp fetch_input({input_key, %{origin: :static, static: rawvalue}}, input_specs, _) do
    %{type: input_type} = Map.fetch!(input_specs, input_key)
    cast_raw_input_to_type(rawvalue, input_type, input_key)
  end

  defp fetch_input({input_key, %{origin: :grid_input}}, input_specs, %{input: rawvalue}) do
    %{type: input_type} = Map.fetch!(input_specs, input_key)

    cast_raw_input_to_type(rawvalue, input_type, input_key)
  end

  defp cast_raw_input_to_type(rawvalue, input_type, input_key) do
    case input_type do
      # in case of a raw type there is no cast to do. This is done to support
      # dev/tests.
      {:raw, _} ->
        {:ok, {input_key, rawvalue}}

      caster when is_atom(caster) ->
        case caster.cast_input(rawvalue) do
          {:ok, value} -> {:ok, {input_key, value}}
          {:error, reason} -> {:error, {:input_cast_error, input_key, input_type, reason}}
          other -> {:error, {:invalid_input_cast, other}}
        end
    end
  end

  # ---------------------------------------------------------------------------
  #  Error Formatting
  # ---------------------------------------------------------------------------

  def format_error({:error, reason}) do
    format_error(reason)
  end

  def format_error({:invalid_inputs, list}) do
    """
    some inputs were invalid:

    - #{Enum.map_join(list, "\n- ", &format_error/1)}
    """
  end

  def format_error({:invalid_injects, list}) do
    """
    some services required for injection were not satisfied:

    - #{Enum.map_join(list, "\n- ", &format_error/1)}
    """
  end

  def format_error({:bad_return, call, result}) do
    """
    invalid value returned

    call:
    #{format_call(call)}:

    returned:
    #{inspect(result)}"

    """
  end

  def format_error(%{__exception__: true} = e), do: Exception.message(e)
  def format_error(message) when is_binary(message), do: message
  def format_error(other), do: inspect(other)

  def format_call({fun, args}) do
    "#{inspect(fun)}(#{Enum.map(args, &inspect/1)})"
  end

  def format_call({m, f, args}) do
    "#{inspect(m)}.#{f}(#{Enum.map(args, &inspect/1)})"
  end

  defp cast_reason({:unmapped, input_key}, act_key) do
    %UnmappedInputError{
      action_key: act_key,
      input_key: input_key
    }
  end

  defp cast_reason({:incompatible_type, input_key, input_type, output_type}, act_key) do
    %InvalidInputTypeError{
      action_key: act_key,
      expected_type: input_type,
      provided_type: output_type,
      input_key: input_key
    }
  end

  defp cast_reason({:no_caster, input_key, input_type, origin}, act_key) do
    %NoInputCasterError{
      action_key: act_key,
      input_key: input_key,
      input_type: input_type,
      origin: origin
    }
  end

  defp cast_reason({:input_cast_error, input_key, input_type, reason}, act_key) do
    %CastError{
      action_key: act_key,
      input_key: input_key,
      input_type: input_type,
      reason: reason
    }
  end

  defp cast_reason({:undef_origin_action, input_key, origin_act}, act_key) do
    %UndefinedOriginActionError{
      action_key: act_key,
      input_key: input_key,
      origin_action_key: origin_act
    }
  end

  defp cast_reason({:service_resolve, inject_key, container_error}, act_key) do
    %UnavailableServiceError{
      action_key: act_key,
      container_error: container_error,
      inject_key: inject_key
    }
  end

  defp cast_reason({:action_failed, act_key, reason}, act_key) do
    %ActionFailureError{
      action_key: act_key,
      reason: reason
    }
  end

  defp cast_error(reason, act_key) do
    mapped = cast_reason(reason, act_key)
    {:error, mapped}
  end
end

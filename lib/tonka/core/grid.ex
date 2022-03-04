defmodule Tonka.Core.Grid do
  alias __MODULE__

  @moduledoc """
  A grid is an execution context for multiple operations.
  """

  defmodule InvalidInputTypeError do
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

  defmodule NoInputCasterError do
    defexception []

    def message(_), do: "the grid has no input caster defined"
  end

  @enforce_keys [:specs, :outputs, :states, :input_caster]
  defstruct @enforce_keys

  def new do
    %Grid{specs: %{}, outputs: %{}, states: %{}, input_caster: nil}
  end

  def set_input(grid, module, spec \\ %{})

  def set_input(%Grid{input_caster: nil} = grid, module, spec) do
    %Grid{grid | input_caster: cast_incast_spec(module, spec)}
  end

  def add_operation(grid, key, module, spec \\ %{})

  def add_operation(%Grid{specs: specs}, key, _module, _spec) when is_map_key(specs, key) do
    raise ArgumentError, "an operation with the key #{inspect(key)} is already defined"
  end

  def add_operation(%Grid{specs: specs} = grid, key, module, spec)
      when is_binary(key) and is_atom(module) do
    spec = cast_op_spec(module, spec)
    specs = Map.put(specs, key, spec)
    %Grid{grid | specs: specs}
  end

  defp cast_op_spec(module, spec) when is_map(spec) do
    spec
    |> Map.put(:module, module)
    |> Map.put_new(:inputs, %{})
    |> Map.put_new(:params, %{})
  end

  defp cast_op_spec(module, spec) when is_list(spec) do
    cast_op_spec(module, Map.new(spec))
  end

  defp cast_incast_spec(module, spec) when is_map(spec) do
    spec
    |> Map.put(:module, module)
    |> Map.put_new(:params, %{})
  end

  defp cast_incast_spec(module, spec) when is_list(spec) do
    cast_incast_spec(module, Map.new(spec))
  end

  def validate(%Grid{} = grid) do
    with :ok <- validate_input_caster(grid),
         :ok <- validate_all_inputs(grid) do
      {:ok, grid}
    end
  end

  def validate!(grid) do
    case validate(grid) do
      {:ok, grid} -> grid
      {:error, {_tag, [%_{} = err | _]}} -> raise err
    end
  end

  defp validate_input_caster(%{input_caster: incast}) do
    case incast do
      nil -> raise NoInputCasterError
      _ -> :ok
    end
  end

  defp validate_all_inputs(%{specs: specs, input_caster: incast}) do
    Enum.reduce(specs, _invalids = [], fn spec, invs ->
      validated = validate_inputs(spec, specs, incast)

      case validated do
        :ok -> invs
        {:error, more_invs} -> more_invs ++ invs
      end
    end)
    |> case do
      [] -> :ok
      invalids -> {:error, {:invalid_inputs, invalids}}
    end
  end

  defp validate_inputs(spec, specs, incast) do
    {op_key, %{module: module, inputs: mapped_inputs}} = spec
    input_specs = module.input_specs()

    input_specs
    |> Enum.map(fn input ->
      source_key = Map.fetch!(mapped_inputs, input.key)

      output =
        case source_key do
          :incast ->
            incast |> IO.inspect(label: "incast")
            %{module: caster_module, params: caster_params} = incast
            caster_params |> IO.inspect(label: "caster_params")
            caster_module.output_spec(caster_params)

          _ ->
            %{module: source_module} = Map.fetch!(specs, source_key)
            source_module.output_spec()
        end

      output |> IO.inspect(label: "output")

      validate_type_compat(input, output, op_key)
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

  defp validate_type_compat(input, output, op_key) do
    %{type: input_type} = input
    %{type: output_type} = output

    if input_type == output_type do
      :ok
    else
      {:error,
       %InvalidInputTypeError{
         op_key: op_key,
         input_key: input.key,
         expected_type: input_type,
         provided_type: output_type
       }}
    end
  end

  def run(%Grid{} = grid, input) do
    outputs = %{input: input}
    states = start_states(grid.specs)
    grid = %Grid{grid | outputs: outputs, states: states}

    grid |> validate!() |> call_input(input) |> run()
  end

  defp call_input(%{input_caster: incast, outputs: outputs} = grid, input) do
    %{module: caster_module, params: caster_params} = incast
    output = caster_module.call(input, caster_params, %{})

    %Grid{grid | outputs: Map.put(outputs, :incast, output)}
  end

  defp start_states(specs) do
    Enum.into(specs, %{}, fn {key, _} -> {key, :uninitialized} end)
  end

  defp run(grid) do
    runnable = find_runnable(grid)
    runnable |> IO.inspect(label: "runnable")

    case runnable do
      {:ok, key} -> grid |> call_op(key) |> run()
      :none -> {:done, grid}
    end
  end

  defp call_op(%{specs: specs, outputs: outputs, states: states} = grid, key) do
    inputs = build_input(grid, key)

    %{module: module, params: params} = Map.fetch!(specs, key)

    output = module.call(inputs, %{Tonka.T.Params => params})

    %Grid{
      grid
      | states: Map.put(states, key, :called),
        outputs: Map.put(outputs, key, output)
    }
  end

  defp find_runnable(%Grid{specs: specs, outputs: outputs, states: states}) do
    states
    |> Enum.filter(fn {_, state} -> state == :uninitialized end)
    |> Enum.map(fn {key, _} -> {key, Map.fetch!(specs, key)} end)
    |> Enum.filter(fn {_key, %{inputs: inputs}} ->
      inputs_keys = Map.values(inputs)
      Enum.all?(inputs_keys, &Map.has_key?(outputs, &1))
    end)
    |> case do
      [{key, _} | _] -> {:ok, key}
      [] -> :none
    end
  end

  defp build_input(%{outputs: outputs, specs: specs}, key) do
    %{inputs: inputs} = Map.fetch!(specs, key)
    Enum.into(inputs, %{}, fn {key, source} -> {key, Map.fetch!(outputs, source)} end)
  end
end

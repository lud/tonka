defmodule Tonka.Core.Action do
  @moduledoc """
  Behaviour defining the callbacks of modules and datatypes used as actions
  in a `Tonka.Core.Grid`.
  """

  alias Tonka.Core.Container.InjectSpec
  alias Tonka.Core.Action.InputSpec
  alias Tonka.Core.Container.ReturnSpec
  alias Tonka.Core.Container.Service.ServiceConfig
  alias __MODULE__

  defmodule ActionConfig do
    @enforce_keys [:service_config, :inputs]
    defstruct @enforce_keys

    @todo "type input specs"

    @type t :: %__MODULE__{
            service_config: ServiceConfig.t(),
            inputs: %{atom => InputSpec.t()}
          }

    def new do
      %__MODULE__{service_config: ServiceConfig.new(), inputs: %{}}
    end
  end

  @type params :: term
  @type action_in :: map
  @type action_out :: action_out(term)
  @type action_out(output) :: {:ok, output} | {:error, term} | {:async, Task.t()}

  @type input_mapping :: %{
          binary => %{
            :origin => :action | :static | :grid_input,
            optional(:static) => term,
            optional(:action) => binary
          }
        }
  @type config :: ActionConfig.t()

  @doc """
  Returns the action configuration:
  * The list of other services types to inject
  * The list of inputs and their configuration

  The params are passed to that function as an help for development and testing.
  The returned configuration defines the arguments of the action `call/3`
  callback, those should not change depending on the params.
  """
  @callback configure(config, params) :: config
  @callback return_type() :: Tonka.Core.Container.typespec()

  @callback call(action_in, injects :: map, params) :: action_out

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour unquote(__MODULE__)
    end
  end

  @enforce_keys [
    :module,
    :params,
    :casted_params,
    :cast_called,
    :config,
    :config_called,
    :input_mapping
  ]
  defstruct @enforce_keys

  @todo "struct typespecs"
  @type t :: %__MODULE__{}

  # defimpl Inspect do
  #   def inspect(%{module: module, casted_params: p, config_called: c} = action, _) do
  #     params = if(p, do: "o", else: "x")
  #     config = if(p, do: "o", else: "x")
  #     "#Action<#{inspect(module)} #{params}#{config}>"
  #   end
  # end

  # ---------------------------------------------------------------------------
  #  Building Action from the Grid
  # ---------------------------------------------------------------------------

  @todo "NimbleOptions"
  @type new_opt :: {:params, term} | {:inputs, input_mapping}
  @type new_opts :: [new_opt]
  @spec new(module, new_opts) :: t()
  def new(module, opts \\ []) when is_atom(module) and is_list(opts) do
    _new(module, Map.merge(empty_vars(), Map.new(opts)))
  end

  defp _new(module, %{params: params, input_mapping: input_mapping}) do
    %__MODULE__{
      module: module,
      params: params,
      casted_params: nil,
      cast_called: false,
      config: nil,
      config_called: false,
      input_mapping: input_mapping
    }
  end

  defp empty_vars do
    %{params: %{}, input_mapping: %{}}
  end

  def precast_params(%Action{cast_called: true} = act) do
    {:ok, act}
  end

  def precast_params(%Action{module: module, params: params} = act) do
    case call_cast_params(module, params) do
      {:ok, casted_params} ->
        {:ok, %Action{act | casted_params: casted_params, cast_called: true}}

      other ->
        other
    end
  end

  defp call_cast_params(module, params) do
    case module.cast_params(params) do
      {:ok, _} = fine -> fine
      {:error, _} = err -> err
      other -> {:error, {:bad_return, {module, :cast_params, [params]}, other}}
    end
  end

  def preconfigure(%Action{config_called: true} = act) do
    {:ok, act}
  end

  def preconfigure(%Action{module: module} = act) do
    with {:ok, %{casted_params: casted_params} = act} <- ensure_params(act),
         {:ok, config} <- call_configure(module, casted_params) do
      {:ok, %Action{act | config: config, config_called: true}}
    end
  end

  defp ensure_params(act) do
    precast_params(act)
  end

  defp call_configure(module, params) do
    base = base_config()

    case module.configure(base_config(), params) do
      %ActionConfig{} = config ->
        {:ok, config}

      other ->
        {:error, {:bad_return, {module, :configure, [base, params]}, other}}
    end
  end

  @doc false
  def base_config,
    do: ActionConfig.new()

  # ---------------------------------------------------------------------------
  #  Configuration API
  # ---------------------------------------------------------------------------

  @use_service_options_schema NimbleOptions.new!([])

  def use_service(%ActionConfig{} = config, key, opts) when is_atom(key) do
    opts = NimbleOptions.validate!(opts, @use_service_options_schema)
  end

  # @input_schema NimbleOptions.new!([])

  @doc """
  Defines an input for the action.


  """
  # ### Options
  # {NimbleOptions.docs(@input_schema)}
  def use_input(%ActionConfig{inputs: inputs} = config, key, utype, opts \\ [])
      when is_atom(key) and is_list(opts) do
    # opts = NimbleOptions.validate!(opts, @input_schema)
    spec = %InputSpec{cast_static: opts[:cast_static], key: key, type: utype}

    if Map.has_key?(inputs, key) do
      raise ArgumentError, "input #{inspect(key)} is already defined"
    end

    %ActionConfig{config | inputs: Map.put(inputs, key, spec)}
  end

  # ---------------------------------------------------------------------------
  #  Calling the action
  # ---------------------------------------------------------------------------

  def call(action, inputs, injects)

  def call(%Action{module: module, casted_params: cparams} = action, inputs, injects)
      when is_map(inputs) and is_map(injects) do
    case module.call(inputs, injects, cparams) do
      {:ok, _} = fine ->
        fine

      {:error, _} = err ->
        err

      other ->
        {:error, {:bad_return, {module, :call, [inputs, cparams, injects]}, other}}
    end
  end
end

defmodule Tonka.Core.Operation do
  @moduledoc """
  Behaviour defining the callbacks of modules and datatypes used as operations
  in a `Tonka.Core.Grid`.
  """

  alias Tonka.Core.Container.InjectSpec
  alias Tonka.Core.Operation.InputSpec
  alias Tonka.Core.Container.ReturnSpec
  alias Tonka.Core.Container.Service.ServiceConfig
  alias __MODULE__

  defmodule OpConfig do
    @enforce_keys [:service_config, :inputs]
    defstruct @enforce_keys

    @todo "type input specs"

    @type t :: %__MODULE__{
            service_config: ServiceConfig.t(),
            inputs: [InputSpec.t()]
          }

    def new do
      %__MODULE__{service_config: ServiceConfig.new(), inputs: []}
    end
  end

  @type params :: term
  @type op_in :: map
  @type op_out :: op_out(term)
  @type op_out(output) :: {:ok, output} | {:error, term} | {:async, Task.t()}

  @type config :: OpConfig.t()

  @doc """
  Returns the operation configuration:
  * The list of other services types to inject
  * The list of inputs and their configuration

  The params are passed to that function as an help for development and testing.
  The returned configuration defines the arguments of the operation `call/3`
  callback, those should not change depending on the params.
  """
  @callback configure(config, params) :: config
  @callback return_spec() :: ReturnSpec.t()

  @callback call(op_in, params, injects :: map) :: op_out

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour unquote(__MODULE__)
    end
  end

  @enforce_keys [:module, :params, :casted_params, :cast_called, :config, :config_called]
  defstruct @enforce_keys

  def new(module, vars \\ []) when is_atom(module) and is_list(vars) do
    _new(module, Map.merge(empty_vars(), Map.new(vars)))
  end

  def _new(module, %{params: params}) do
    %__MODULE__{
      module: module,
      params: params,
      casted_params: nil,
      cast_called: false,
      config: nil,
      config_called: false
    }
  end

  defp empty_vars do
    %{params: %{}}
  end

  def precast_params(%Operation{cast_called: true} = op) do
    {:ok, op}
  end

  def precast_params(%Operation{module: module, params: params} = op) do
    case call_cast_params(module, params) do
      {:ok, casted_params} ->
        {:ok, %Operation{op | casted_params: casted_params, cast_called: true}}

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

  def preconfigure(%Operation{config_called: true} = op) do
    {:ok, op}
  end

  def preconfigure(%Operation{module: module} = op) do
    with {:ok, %{casted_params: casted_params} = op} <- ensure_params(op),
         {:ok, config} <- call_configure(module, casted_params) do
      {:ok, %Operation{op | config: config, config_called: true}}
    end
  end

  defp ensure_params(op) do
    precast_params(op)
  end

  defp call_configure(module, params) do
    base = base_config()

    case module.configure(base_config(), params) do
      %OpConfig{} = config -> {:ok, config}
      other -> {:error, {:bad_return, {module, :configure, [base, params]}, other}}
    end
  end

  @doc false
  def base_config,
    do: OpConfig.new()

  # ---------------------------------------------------------------------------
  #  Configuration API
  # ---------------------------------------------------------------------------

  @use_service_options_schema NimbleOptions.new!([])

  def use_service(%OpConfig{} = config, key, opts) when is_atom(key) do
    opts = NimbleOptions.validate!(opts, @use_service_options_schema)
  end

  # @input_schema NimbleOptions.new!([])

  @doc """
  Defines an input for the operation.


  """
  # ### Options
  # {NimbleOptions.docs(@input_schema)}
  def use_input(%OpConfig{inputs: inputs} = config, key, utype, opts \\ [])
      when is_atom(key) and is_list(opts) do
    # opts = NimbleOptions.validate!(opts, @input_schema)
    spec = %InputSpec{cast_static: opts[:cast_static], key: key, type: utype}
    inputs = [spec | inputs]
    %OpConfig{config | inputs: inputs}
  end
end

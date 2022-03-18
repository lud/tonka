defmodule Tonka.Core.Operation do
  @moduledoc """
  Behaviour defining the callbacks of modules and datatypes used as operations
  in a `Tonka.Core.Grid`.
  """

  alias Tonka.Core.Container.InjectSpec
  alias Tonka.Core.Container.ReturnSpec
  alias __MODULE__

  @type params :: map
  @type op_in :: map
  @type op_out :: op_out(term)
  @type op_out(output) :: {:ok, output} | {:error, term} | {:async, Task.t()}

  @callback input_specs() :: [InjectSpec.t()]
  @callback output_spec() :: ReturnSpec.t()

  @callback call(op_in, params, injects :: map) :: op_out

  defmacro __using__(_) do
    quote location: :keep do
    end
  end

  @enforce_keys [:module, :params, :casted_params, :cast_called]
  defstruct @enforce_keys

  def new(module, vars \\ []) when is_atom(module) and is_list(vars) do
    _new(module, Map.merge(empty_vars(), Map.new(vars)))
  end

  def _new(module, %{params: params}) do
    %__MODULE__{module: module, params: params, casted_params: nil, cast_called: false}
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

  # def build(
  #       %Operation{params: params, module: module} = service,
  #       container
  #     )
  #     when is_atom(module) do
  #   # We do not store the casted params, because if we need to rebuild a service
  #   # we can just reuse the current struct by flipping the built flag to false.

  #   with {:ok, casted_params} <- call_cast_params(module, params),
  #        {:ok, %{injects: inject_specs}} <- call_config(module, casted_params),
  #        {:ok, injects, new_container} <- build_injects(container, inject_specs, overrides),
  #        {:ok, impl} <- init_module(module, injects, casted_params) do
  #     {:ok, as_built(service, impl), new_container}
  #   else
  #     {:error, _} = err -> err
  #   end
  # end
end

defmodule Tonka.Core.InputCaster do
  alias Tonka.Core.Operation
  alias __MODULE__

  @moduledoc """
  This behaviour describes a special kind of `Tonka.Core.Operation` that must
  accept a single untyped term as its input and tries to cast it to the type
  described by the `c:output_spec/0` callback.

  It is used as the input acceptor in a `Tonka.Core.Grid`, and its output value
  will be passed as input to all grid operations that have `:incast` in their
  `:inputs` mapping.
  """

  @enforce_keys [:module, :output_spec]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          module: module,
          output_spec: Container.ReturnSpec.t()
        }

  @type buildable :: t | module
  @type new_opt :: {:module, module} | {:output_spec, Container.ReturnSpec.t()}
  @type new_opts :: [new_opt]

  @callback output_spec() :: Container.ReturnSpec.t()
  @callback call(term, Operation.params(), injects :: map) :: Operation.op_out()

  @spec new(new_opts) :: t
  def new(opts) do
    struct!(__MODULE__, opts)
  end

  @spec build(buildable) :: t
  def build(module) when is_atom(module) do
    new(module: module, output_spec: module.output_spec())
  end

  def build(%InputCaster{} = this) do
    this
  end

  def call(%InputCaster{module: module}, input, params, injects) do
    module.call(input, params, injects)
  end
end

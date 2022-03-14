defmodule Tonka.Core.Container.Service do
  alias __MODULE__
  alias Tonka.Core.Injector
  alias Tonka.Core.Container.InjectSpec
  alias Tonka.Core.Container

  @type impl :: term
  @type service :: service(term)
  @type service(impl) :: {:ok, impl} | {:error, term}

  @callback provides_spec :: Tonka.Core.Container.ReturnSpec.t()
  @callback inject_specs(
              function :: atom,
              arity :: non_neg_integer,
              arg_0n :: non_neg_integer
            ) :: [InjectSpec.t()]

  @callback init(map) :: service(term)

  @enforce_keys [:built, :builder, :impl, :overrides]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          built: boolean,
          builder: module,
          impl: term
        }

  defmacro __using__(_) do
    quote location: :keep do
      import Tonka.Core.Container.Service.ServiceMacros
      Tonka.Core.Container.Service.ServiceMacros.init_module()
    end
  end

  def new(opts) do
    struct!(__MODULE__, opts)
  end

  @doc false
  def inject_specs(module) when is_atom(module) do
    module.inject_specs(:init, 1, 0)
  end
end

defmodule Tonka.Ext.Gitlab.Issues do
  use Tonka.Core.Container.Service
  alias Tonka.Service.IssuesSource

  provides Tonka.Service.IssuesSource

  @enforce_keys [:projects, :private_token]
  @derive IssuesSource
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          projects: [binary()],
          private_token: binary
        }

  inject params in Tonka.Core.Container.Params

  def new(opts) do
    struct!(__MODULE__, opts)
  end

  @params_caster Hugs.build_props()
                 |> Hugs.field(:projects, type: {:list, :binary}, required: true)

  def cast_params(params) do
    Hugs.denormalize(params, @params_caster)
  end

  init do
    {:ok, new(projects: params.projects)}
  end
end

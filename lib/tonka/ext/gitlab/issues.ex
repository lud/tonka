defmodule Tonka.Ext.Gitlab.Issues do
  use Tonka.Core.Container.Service
  alias Tonka.Service.IssuesSource

  provides Tonka.Service.IssuesSource

  @enforce_keys [:projects]
  @derive IssuesSource
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          projects: [binary()]
        }

  inject params in Tonka.Core.Container.Params

  defp new(opts) do
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

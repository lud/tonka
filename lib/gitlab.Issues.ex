defmodule Tonka.Ext.Gitlab.Issues do
  use Tonka.Core.Container.Service
  alias Tonka.Service.IssuesSource

  defmodule GitlabIssuesParams do
    require Hugs
  end

  provides(Tonka.Service.IssuesSource)

  @enforce_keys [:projects]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          projects: [binary()]
        }

  inject(params in Tonka.Core.Container.Params)

  defp new(opts) do
    struct!(__MODULE__, opts)
  end

  def cast_params(params) do
    Hugs.build_props()
    |> Hugs.field(:projects, type: {:list, :binary}, required: true)
    |> Hugs.denormalize_data(params)
  end

  init do
    {:ok, new(projects: params.projects)}
  end
end

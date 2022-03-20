defmodule Tonka.Ext.Gitlab.Issues do
  use Tonka.Core.Container.Service
  alias Tonka.Service.IssuesSource

  @enforce_keys [:projects, :private_token]
  @derive IssuesSource
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          projects: [binary()],
          private_token: binary
        }

  def new(opts) do
    struct!(__MODULE__, opts)
  end

  def configure(config, _params) do
    config
    |> Service.use_service(:credentials, Tonka.Service.Credentials)
  end

  def init(%{credentials: credentials}, %{credentials: path, projects: projects}) do
    {:ok,
     new(
       private_token: Tonka.Service.Credentials.get_string(credentials, path),
       projects: projects
     )}
  end

  @params_caster Hugs.build_props()
                 |> Hugs.field(:projects, type: {:list, :binary}, required: true)
                 |> Hugs.field(:credentials, type: :binary, required: true)

  def cast_params(params) do
    Hugs.denormalize(params, @params_caster)
  end
end

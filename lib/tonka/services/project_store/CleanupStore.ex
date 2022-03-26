defmodule Tonka.Services.CleanupStore do
  alias Tonka.Services.ProjectStore

  defmodule CleanupParams do
    require Hugs

    Hugs.build_struct()
    |> Hugs.field(:key, type: :binary, required: true)
    |> Hugs.inject()
  end

  @type action_module :: module()
  @type cleanup_params :: CleanupParams.t()
  @type inputs :: Action.inputs()
  @type key :: binary()
  @type cleanup_data :: term
  @type id :: integer

  @enforce_keys [:pstore]
  defstruct @enforce_keys
  @type t :: %__MODULE__{pstore: ProjectStore.t()}

  @spec compute_key(action_module, cleanup_params, inputs()) :: key
  def compute_key(module, params, inputs) do
    CleanupParams.new(params).key
  end

  @spec put_cleanup(t, key, cleanup_data) :: :ok
  def put_cleanup(t, key, cleanup_data) do
  end

  @spec list_cleanups(t, key) :: [{id, cleanup_data}]
  def list_cleanups(t, key) do
  end

  @spec delete_cleanup(t, key, id) :: :ok
  def delete_cleanup(t, key, id) do
  end
end

defmodule Tonka.Services.ProjectStore.Record do
  # Disaled module, only useful if we need postgresql
  @todo "implement or remove"
  @moduledoc false

  # use Ecto.Schema

  # @type t :: %__MODULE__{}
  # # The project store must rely on an implementation to put and get values for
  # # services and actions.
  # #
  # # writing and reading a key should rely on the following columns

  # embedded_schema do
  #   # Stores the project identifier. As long as we are using CubDB and
  #   # directories for configuration this is just a string and it is not actually
  #   # persisted since each project has its own store. Later implementation would
  #   # need a binary_id or a PG serial.
  #   field :project_id, :string

  #   # Stores the name of the service or action that uses the storage, so there
  #   # is no conflict betweens simple keys like "date" or "username" between
  #   # different actions or services.
  #   #
  #   # e.g. "CleanupStore" or "ProjectScheduler"
  #   field :component, :string

  #   # Stores the key of the stored value. The column in database will be named
  #   # "storage_key".
  #   field :key, :string, source: :storage_key

  #   # Stores the actual value as a map. term-to-binary storage would be simpler
  #   # but seeing the actual values in database when debugging is worth the
  #   # effort. Term-to-binary values can be embedded in JSON as base-64 encoded
  #   # strings (although the perofmance cost is high).
  #   field :value, :map
  # end

  # def new(project_id, component, key, value) do
  #   %__MODULE__{
  #     project_id: project_id,
  #     component: component,
  #     key: key,
  #     value: value
  #   }
  # end
end

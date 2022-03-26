defmodule Tonka.Services.ProjectStore do
  use Ecto.Schema

  # The project store must rely on an implementation to put and get values for
  # services and actions.
  #
  # writing and reading a key should rely on the following columns

  schema "project_storage" do
    # Stores the project identifier. As long as we are using CubDB and
    # directories for configuration this is just a string.  Later implementation
    # would need a binary_id or a PG serial.
    field :project_id, :string

    # Stores the name of the service or action that uses the storage, so there
    # is no conflict betweens simple keys like "date" or "username" between
    # different actions or services.
    #
    # e.g. "CleanupStore" or "ProjectScheduler"
    field :component, :string

    # Stores the key of the stored value. It could just be named "key" but that
    # could be confusing.
    field :storage_key, :string

    # Stores the actual value as a map. term-to-binary storage would be simpler
    # but seeing the actual values in database when debugging is worth the
    # effort. Term-to-binary values can be embedded in JSON as base-64 encoded
    # strings (although the perofmance cost is high).
    field :storage_value, :map
  end
end

defmodule Tonka.Services.CleanupStore.CleanupParams do
  require Hugs
  alias Tonka.Data.TimeInterval

  Hugs.build_struct()
  |> Hugs.field(:key, type: :binary, required: true)
  |> Hugs.field(:ttl, type: :integer, default: 0, cast: &TimeInterval.to_ms/1)
  |> Hugs.field(:inputs,
    type: {:list, :atom},
    default: [],
    cast: {:list, &Hugs.Cast.string_to_existing_atom/1}
  )
  |> Hugs.inject()
end

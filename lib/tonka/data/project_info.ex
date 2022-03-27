defmodule Tonka.Data.ProjectInfo do
  require Hugs

  Hugs.build_struct()
  |> Hugs.field(:prk, type: :binary, required: true)
  |> Hugs.field(:storage_dir, type: :binary, required: true)
  |> Hugs.inject()
end

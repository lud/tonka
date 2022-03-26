defmodule Tonka.Data.ProjectInfo do
  require Hugs
  use Tonka.Core.Container.Type

  Hugs.build_struct()
  |> Hugs.field(:id, type: :binary, required: true)
  |> Hugs.field(:storage_dir, type: :binary, required: true)
  |> Hugs.inject()
end

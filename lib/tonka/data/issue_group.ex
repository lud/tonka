defmodule Tonka.Data.IssueGroup do
  require Hugs
  use Tonka.Core.Container.Type

  Hugs.build_struct()
  |> Hugs.field(:issues, type: {:list, Tonka.Data.Issue}, required: true)
  |> Hugs.field(:title, type: :binary, required: true)
  |> Hugs.inject()
end
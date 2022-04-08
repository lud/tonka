defmodule Tonka.Data.IssuesGroup do
  require Hugs

  Hugs.build_struct()
  |> Hugs.field(:issues, type: {:list, Tonka.Data.Issue}, required: true)
  |> Hugs.field(:title, type: :binary, required: true)
  |> Hugs.field(:remain, type: :integer, default: nil)
  |> Hugs.define()
end

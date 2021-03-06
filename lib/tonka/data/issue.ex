defmodule Tonka.Data.Issue do
  require Hugs

  Hugs.build_struct()
  |> Hugs.field(:id, type: :binary, required: true)
  |> Hugs.field(:title, type: :binary, required: true)
  |> Hugs.field(:iid, type: :binary, required: true)
  |> Hugs.field(:url, type: :binary, required: true)
  |> Hugs.field(:last_ext_username, type: :binary, required: false, default: nil)
  |> Hugs.field(:last_user_id, type: :binary, required: false, default: nil)
  |> Hugs.field(:assignee_ext_username, type: :binary, required: false, default: nil)
  |> Hugs.field(:assignee_user_id, type: :binary, required: false, default: nil)
  |> Hugs.field(:labels, type: {:list, :binary})
  |> Hugs.field(:updated_at, type: DateTime, cast: &Hugs.Cast.datetime_from_iso8601/1)
  |> Hugs.field(:status, type: {:enum, ["open", "closed"]}, required: true)
  |> Hugs.define()
end

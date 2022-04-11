defmodule Tonka.Data.ProjectInfo do
  require Hugs

  @todo "everything required"
  @todo "hide credentials in closure, test if closure can leak info"

  Hugs.build_struct()
  |> Hugs.field(:prk, type: :binary, required: true)
  |> Hugs.field(:storage_dir, type: :binary, required: true)
  |> Hugs.field(:yaml_path, type: :binary)
  |> Hugs.field(:credentials_path, type: :binary)
  |> Hugs.field(:service_sup_name, type: :any)
  |> Hugs.field(:job_sup_name, type: :any)
  |> Hugs.field(:store_backend_name, type: :any)
  |> Hugs.define()
end

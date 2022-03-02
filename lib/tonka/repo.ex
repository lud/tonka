defmodule Tonka.Repo do
  use Ecto.Repo,
    otp_app: :tonka,
    adapter: Ecto.Adapters.Postgres
end

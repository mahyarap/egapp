defmodule Egapp.Repo do
  use Ecto.Repo,
    otp_app: :egapp,
    adapter: Ecto.Adapters.Postgres
end

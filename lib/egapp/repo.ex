defmodule Egapp.Repo do
  @moduledoce false

  use Ecto.Repo,
    otp_app: :egapp,
    adapter: Ecto.Adapters.Postgres
end

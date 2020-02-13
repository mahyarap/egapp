defmodule Egapp.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :egapp,
    adapter: Ecto.Adapters.Postgres
end

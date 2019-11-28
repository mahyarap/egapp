defmodule Egapp.Repo.Roster do
  use Ecto.Schema

  schema "rosters" do
    field :version, :integer
    belongs_to :user, Egapp.Repo.User
  end
end

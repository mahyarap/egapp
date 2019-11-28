defmodule Egapp.Repo.Roster do
  use Ecto.Schema

  schema "rosters" do
    field :version, :integer
    belongs_to :user, Egapp.Repo.User
    many_to_many :users, Egapp.Repo.User, join_through: "users_rosters"
  end
end

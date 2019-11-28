defmodule Egapp.Repo.User do
  use Ecto.Schema

  schema "users" do
    field :first_name, :string
    field :last_name, :string
    field :username, :string
    field :password, :string
    has_one :roster, Egapp.Repo.Roster
    many_to_many :rosters, Egapp.Repo.Roster, join_through: "users_rosters"
  end
end

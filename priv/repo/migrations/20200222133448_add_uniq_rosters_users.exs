defmodule Egapp.Repo.Migrations.AddUniqRostersUsers do
  use Ecto.Migration

  def change do
    create unique_index(:users_rosters, [:user_id, :roster_id])
  end
end

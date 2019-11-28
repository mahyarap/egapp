defmodule Egapp.Repo.Migrations.CreateUsersRosters do
  use Ecto.Migration

  def change do
    create table(:users_rosters) do
      add :user_id, references(:users)
      add :roster_id, references(:rosters)
    end
  end
end

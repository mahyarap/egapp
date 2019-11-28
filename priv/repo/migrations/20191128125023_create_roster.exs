defmodule Egapp.Repo.Migrations.CreateRoster do
  use Ecto.Migration

  def change do
    create table(:rosters) do
      add :user_id, references(:users)
      add :version, :integer
    end
  end
end

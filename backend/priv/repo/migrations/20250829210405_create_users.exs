defmodule Backend.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :username, :string, null: false
      add :balance, :decimal, precision: 10, scale: 2, null: false

      timestamps()
    end

    create unique_index(:users, [:username])
  end
end

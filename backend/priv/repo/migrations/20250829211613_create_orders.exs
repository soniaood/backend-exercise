defmodule Backend.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def change do
    create table(:orders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id), null: false
      add :total, :decimal, precision: 10, scale: 2, null: false

      timestamps()
    end

    create index(:orders, [:user_id])
  end
end

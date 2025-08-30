defmodule Backend.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :price, :decimal, precision: 10, scale: 2, null: false

      timestamps()
    end
  end
end

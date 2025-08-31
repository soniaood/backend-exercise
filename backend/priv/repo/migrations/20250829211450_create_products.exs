defmodule Backend.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :string, null: false
      add :price, :decimal, precision: 10, scale: 2, null: false

      timestamps()
    end

    create unique_index(:products, [:name], name: :products_name_unique)
  end
end

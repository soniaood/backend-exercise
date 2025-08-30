defmodule Backend.Repo.Migrations.CreateUserProducts do
  use Ecto.Migration

  def change do
    create table(:user_products, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id), null: false
      add :product_id, references(:products, type: :string), null: false
      add :order_id, references(:orders, type: :binary_id), null: false

      timestamps()
    end

    create unique_index(:user_products, [:user_id, :product_id])
    create index(:user_products, [:user_id])
  end
end

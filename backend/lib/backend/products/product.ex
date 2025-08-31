defmodule Backend.Products.Product do
  @moduledoc """
  Ecto schema for products.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "products" do
    field :name, :string
    field :description, :string
    field :price, :decimal

    has_many :order_items, Backend.Orders.OrderItem
    has_many :user_products, Backend.Users.UserProduct

    timestamps()
  end

  def changeset(product, attrs) do
    product
    |> cast(attrs, [:name, :description, :price])
    |> validate_required([:name, :description, :price])
    |> validate_number(:price, greater_than: 0)
    |> unique_constraint(:name)
  end
end

defmodule Backend.Products.Product do
  @moduledoc """
  Ecto schema for products.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}

  schema "products" do
    field :name, :string
    field :price, :decimal

    has_many :order_items, Backend.Orders.OrderItem
    has_many :user_products, Backend.Users.UserProduct

    timestamps()
  end

  def changeset(product, attrs) do
    product
    |> cast(attrs, [:id, :name, :price])
    |> validate_required([:id, :name, :price])
    |> validate_number(:price, greater_than: 0)
  end
end

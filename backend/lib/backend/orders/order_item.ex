defmodule Backend.Orders.OrderItem do
  @moduledoc """
  Ecto schema for order items.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "order_items" do
    field :price, :decimal

    belongs_to :order, Backend.Orders.Order
    belongs_to :product, Backend.Products.Product

    timestamps()
  end

  def changeset(order_item, attrs) do
    order_item
    |> cast(attrs, [:price, :order_id, :product_id])
    |> validate_required([:price, :order_id, :product_id])
    |> validate_number(:price, greater_than: 0)
  end
end

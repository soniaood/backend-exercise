defmodule Backend.Users.UserProduct do
  @moduledoc """
  Ecto schema for products associated to an user and an order.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_products" do
    belongs_to :user, Backend.Users.User
    belongs_to :product, Backend.Products.Product
    belongs_to :order, Backend.Orders.Order

    timestamps()
  end

  def changeset(user_product, attrs) do
    user_product
    |> cast(attrs, [:user_id, :product_id, :order_id])
    |> validate_required([:user_id, :product_id, :order_id])
    |> unique_constraint([:user_id, :product_id])
  end
end

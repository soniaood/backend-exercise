defmodule Backend.Orders.Order do
  @moduledoc """
  Ecto schema for orders.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "orders" do
    field :total, :decimal

    belongs_to :user, Backend.Users.User
    has_many :order_items, Backend.Orders.OrderItem

    timestamps()
  end

  def changeset(order, attrs) do
    order
    |> cast(attrs, [:total, :user_id])
    |> validate_required([:total, :user_id])
    |> validate_number(:total, greater_than: 0)
  end
end

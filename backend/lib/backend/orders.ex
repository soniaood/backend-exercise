defmodule Backend.Orders do
  @moduledoc """
  Orders context.

  Orchestrates order creation and validation within a single database transaction:
  — Validates product existence and prevents re-purchase of already owned items
  — Verifies user balance is enough and updates it
  — Persists the `order`, its `order_items`, and user-product ownership

  Also exposes read helpers to retrieve orders with their items and products.
  """

  import Ecto.Query
  alias Backend.Repo
  alias Backend.Orders.{Order, OrderItem}
  alias Backend.{Users, Products}
  alias Ecto.Multi

  def create_order(user_username, product_ids) do
    Multi.new()
    |> Multi.run(:user, fn _repo, _changes ->
      Users.get_user_by_username(user_username)
    end)
    |> Multi.run(:products, fn _repo, _changes ->
      products = Products.get_products_by_ids(product_ids)

      if length(products) != length(product_ids) do
        {:error, :products_not_found}
      else
        {:ok, products}
      end
    end)
    |> Multi.run(:validate_products, fn _repo, %{user: user, products: products} ->
      user_product_ids = Users.get_user_product_ids(user)
      already_purchased = Enum.filter(products, fn p -> p.id in user_product_ids end)

      if length(already_purchased) > 0 do
        {:error, :products_already_purchased}
      else
        {:ok, products}
      end
    end)
    |> Multi.run(:validate_balance, fn _repo, %{user: user, products: products} ->
      total = products |> Enum.map(& &1.price) |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

      if Decimal.compare(user.balance, total) == :lt do
        {:error, :insufficient_balance}
      else
        {:ok, {products, total}}
      end
    end)
    |> Multi.run(:order, fn _repo, %{user: user, validate_balance: {_products, total}} ->
      %Order{}
      |> Order.changeset(%{user_id: user.id, total: total})
      |> Repo.insert()
    end)
    |> Multi.run(:order_items, fn _repo, %{order: order, validate_balance: {products, _total}} ->
      order_items =
        Enum.map(products, fn product ->
          %{
            order_id: order.id,
            product_id: product.id,
            price: product.price,
            inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
            updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          }
        end)

      {count, _} = Repo.insert_all(OrderItem, order_items)
      {:ok, count}
    end)
    |> Multi.run(:user_products, fn _repo,
                                    %{
                                      user: user,
                                      order: order,
                                      validate_balance: {products, _total}
                                    } ->
      product_ids = Enum.map(products, & &1.id)
      Users.add_user_products(user.id, product_ids, order.id)
      {:ok, product_ids}
    end)
    |> Multi.run(:update_balance, fn _repo, %{user: user, validate_balance: {_products, total}} ->
      new_balance = Decimal.sub(user.balance, total)
      Users.update_user_balance(user, new_balance)
    end)
    |> Repo.transaction()
  end

  def get_order_with_items(order_id) do
    query =
      from o in Order,
        where: o.id == ^order_id,
        preload: [order_items: :product]

    Repo.one(query)
  end
end

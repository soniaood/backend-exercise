defmodule Backend.Orders do
  @moduledoc """
  Orders context.

  Orchestrates order creation and validation within a single database transaction:
  1. :user. Fetch user with products by id
  2. :products. Validate all products exist
  3. :validate_products. Check the user doesn't already own them
  4. :validate_balance. Ensure the user has sufficient funds
  5. :order. Create the order record
  6. :order_items. Insert order items
  7. :user_products. Record user ownership
  8. :update_balance. Deduct from user balance

  Dev notes:
  Also exposes read helpers to retrieve orders with their items and products.

  Multi.run is part of Elixir's Ecto.Multi, which provides a way to compose multiple
  database operations into a single atomic transaction.

  Each Multi.run step:
  — Executes a function that can access results from previous steps
  — Must return {:ok, result} or {:error, reason}
  — If any step fails, the entire transaction is rolled back
  — Steps have access to accumulated results via the second parameter
  """

  import Ecto.Query
  alias Backend.Repo
  alias Backend.Orders.{Order, OrderItem}
  alias Backend.{Users, Products}
  alias Ecto.Multi

  def create_order(user_id, product_ids) do
    Multi.new()
    |> Multi.run(:validate_input, fn _repo, _changes ->
      cond do
        is_nil(product_ids) or product_ids == [] ->
          {:error, :empty_product_list}

        !is_list(product_ids) ->
          {:error, :invalid_product_list}

        length(product_ids) != length(Enum.uniq(product_ids)) ->
          {:error, :duplicate_products_in_request}

        true ->
          {:ok, product_ids}
      end
    end)
    |> Multi.run(:user, fn _repo, _changes ->
      case Users.get_user_with_products(user_id) do
        %Backend.Users.User{} = user -> {:ok, user}
        nil -> {:error, :user_not_found}
      end
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
      user_product_ids = Enum.map(user.user_products, & &1.product_id)
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

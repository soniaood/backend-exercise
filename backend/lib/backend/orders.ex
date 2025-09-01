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
    |> add_input_validation_step(product_ids)
    |> add_user_fetching_step(user_id)
    |> add_products_fetching_step(product_ids)
    |> add_ownership_validation_step()
    |> add_balance_validation_step()
    |> add_order_creation_step()
    |> add_order_items_creation_step()
    |> add_user_products_creation_step()
    |> add_balance_update_step()
    |> Repo.transaction()
  end

  defp add_input_validation_step(multi, product_ids) do
    Multi.run(multi, :validate_input, fn _repo, _changes ->
      validate_input(product_ids)
    end)
  end

  defp add_user_fetching_step(multi, user_id) do
    Multi.run(multi, :user, fn _repo, _changes ->
      fetch_user_with_products(user_id)
    end)
  end

  defp add_products_fetching_step(multi, product_ids) do
    Multi.run(multi, :products, fn _repo, _changes ->
      fetch_and_validate_products(product_ids)
    end)
  end

  defp add_ownership_validation_step(multi) do
    Multi.run(multi, :validate_products, fn _repo, %{user: user, products: products} ->
      validate_product_ownership(user, products)
    end)
  end

  defp add_balance_validation_step(multi) do
    Multi.run(multi, :validate_balance, fn _repo, %{user: user, products: products} ->
      validate_user_balance(user, products)
    end)
  end

  defp add_order_creation_step(multi) do
    Multi.run(multi, :order, fn _repo, %{user: user, validate_balance: {_products, total}} ->
      create_order_record(user.id, total)
    end)
  end

  defp add_order_items_creation_step(multi) do
    Multi.run(multi, :order_items, fn _repo,
                                      %{order: order, validate_balance: {products, _total}} ->
      create_order_items(order.id, products)
    end)
  end

  defp add_user_products_creation_step(multi) do
    Multi.run(multi, :user_products, fn _repo,
                                        %{
                                          user: user,
                                          order: order,
                                          validate_balance: {products, _total}
                                        } ->
      create_user_products(user.id, products, order.id)
    end)
  end

  defp add_balance_update_step(multi) do
    Multi.run(multi, :update_balance, fn _repo,
                                         %{user: user, validate_balance: {_products, total}} ->
      update_user_balance(user, total)
    end)
  end

  # Individual validation and operation functions
  defp validate_input(product_ids) do
    cond do
      is_nil(product_ids) or product_ids == [] ->
        {:error, :empty_product_list}

      !is_list(product_ids) ->
        {:error, :invalid_product_list}

      product_ids != Enum.uniq(product_ids) ->
        {:error, :duplicate_products_in_request}

      true ->
        {:ok, product_ids}
    end
  end

  defp fetch_user_with_products(user_id) do
    case Users.get_user_with_products(user_id) do
      %Backend.Users.User{} = user -> {:ok, user}
      nil -> {:error, :user_not_found}
    end
  end

  defp fetch_and_validate_products(product_ids) do
    products = Products.get_products_by_ids(product_ids)
    found_ids = Enum.map(products, & &1.id) |> MapSet.new()
    requested_ids = MapSet.new(product_ids)

    if MapSet.equal?(found_ids, requested_ids) do
      {:ok, products}
    else
      {:error, :products_not_found}
    end
  end

  defp validate_product_ownership(user, products) do
    user_product_ids = Enum.map(user.user_products, & &1.product_id)
    already_purchased = Enum.filter(products, fn p -> p.id in user_product_ids end)

    if Enum.empty?(already_purchased) do
      {:ok, products}
    else
      {:error, :products_already_purchased}
    end
  end

  defp validate_user_balance(user, products) do
    total = calculate_total_price(products)

    if Decimal.compare(user.balance, total) != :lt do
      {:ok, {products, total}}
    else
      {:error, :insufficient_balance}
    end
  end

  defp create_order_record(user_id, total) do
    %Order{}
    |> Order.changeset(%{user_id: user_id, total: total})
    |> Repo.insert()
  end

  defp create_order_items(order_id, products) do
    timestamp = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    order_items =
      Enum.map(products, fn product ->
        %{
          order_id: order_id,
          product_id: product.id,
          price: product.price,
          inserted_at: timestamp,
          updated_at: timestamp
        }
      end)

    {count, _} = Repo.insert_all(OrderItem, order_items)
    {:ok, count}
  end

  defp create_user_products(user_id, products, order_id) do
    product_ids = Enum.map(products, & &1.id)
    Users.add_user_products(user_id, product_ids, order_id)
    {:ok, product_ids}
  end

  defp update_user_balance(user, total) do
    new_balance = Decimal.sub(user.balance, total)
    Users.update_user_balance(user, new_balance)
  end

  defp calculate_total_price(products) do
    products
    |> Enum.map(& &1.price)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
  end

  def get_order_with_items(order_id) do
    query =
      from o in Order,
        where: o.id == ^order_id,
        preload: [order_items: :product]

    Repo.one(query)
  end
end

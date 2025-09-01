defmodule Backend.OrdersTest do
  use Backend.DataCase, async: true

  alias Backend.Orders
  alias Backend.Orders.{Order, OrderItem}
  alias Backend.Products.Product
  alias Backend.Users.{User, UserProduct}

  setup do
    {:ok, user} =
      Repo.insert(%User{
        username: "testuser",
        email: "test@example.com",
        password_hash: Bcrypt.hash_pwd_salt("Password123!"),
        balance: Decimal.new("100.00")
      })

    {:ok, product1} =
      Repo.insert(%Product{
        name: "product1",
        description: "Product 1",
        price: Decimal.new("10.00")
      })

    {:ok, product2} =
      Repo.insert(%Product{
        name: "product2",
        description: "Product 2",
        price: Decimal.new("20.00")
      })

    {:ok, product3} =
      Repo.insert(%Product{
        name: "product3",
        description: "Product 3",
        price: Decimal.new("15.00")
      })

    %{user: user, product1: product1, product2: product2, product3: product3}
  end

  describe "create_order/2" do
    test "successfully creates order with valid data", %{
      user: user,
      product1: product1,
      product2: product2
    } do
      product_ids = [product1.id, product2.id]

      assert {:ok, %{order: order}} = Orders.create_order(user.id, product_ids)

      assert order.user_id == user.id
      assert order.total == Decimal.new("30.00")

      # Verify order items were created
      order_items = Repo.all(OrderItem)
      assert length(order_items) == 2

      # Verify user products were added
      user_products = Repo.all(UserProduct)
      assert length(user_products) == 2

      # Verify user balance was updated
      updated_user = Repo.get(User, user.id)
      assert updated_user.balance == Decimal.new("70.00")
    end

    test "returns error when user not found" do
      fake_user_id = Ecto.UUID.generate()
      product_ids = [Ecto.UUID.generate()]

      assert {:error, :user, :user_not_found, _} =
               Orders.create_order(fake_user_id, product_ids)
    end

    test "returns error when products not found", %{user: user} do
      fake_uuid1 = Ecto.UUID.generate()
      fake_uuid2 = Ecto.UUID.generate()
      product_ids = [fake_uuid1, fake_uuid2]

      assert {:error, :products, :products_not_found, _} =
               Orders.create_order(user.id, product_ids)
    end

    test "returns error when some products not found", %{user: user, product1: product1} do
      fake_uuid = Ecto.UUID.generate()
      product_ids = [product1.id, fake_uuid]

      assert {:error, :products, :products_not_found, _} =
               Orders.create_order(user.id, product_ids)
    end

    test "returns error when user already purchased products", %{
      user: user,
      product1: product1,
      product2: product2
    } do
      # First purchase
      {:ok, order} =
        Repo.insert(%Order{user_id: user.id, total: Decimal.new("10.00")})

      Repo.insert(%UserProduct{user_id: user.id, product_id: product1.id, order_id: order.id})

      product_ids = [product1.id, product2.id]

      assert {:error, :validate_products, :products_already_purchased, _} =
               Orders.create_order(user.id, product_ids)
    end

    test "returns error when insufficient balance", %{
      user: user,
      product1: product1,
      product2: product2,
      product3: product3
    } do
      # Update user balance to be insufficient
      Repo.update!(User.changeset(user, %{balance: Decimal.new("20.00")}))

      # Total: 45.00 (10 + 20 + 15)
      product_ids = [product1.id, product2.id, product3.id]

      assert {:error, :validate_balance, :insufficient_balance, _} =
               Orders.create_order(user.id, product_ids)
    end

    test "handles exact balance match", %{user: user, product1: product1, product2: product2} do
      # Update user balance to exact amount needed
      Repo.update!(User.changeset(user, %{balance: Decimal.new("30.00")}))

      # Total: 30.00
      product_ids = [product1.id, product2.id]

      assert {:ok, %{order: _order}} = Orders.create_order(user.id, product_ids)

      updated_user = Repo.get(User, user.id)
      assert updated_user.balance == Decimal.new("0.00")
    end

    test "handles single product purchase", %{user: user, product1: product1} do
      product_ids = [product1.id]

      assert {:ok, %{order: order}} = Orders.create_order(user.id, product_ids)

      assert order.total == Decimal.new("10.00")

      order_items = Repo.all(OrderItem)
      assert length(order_items) == 1
      assert hd(order_items).product_id == product1.id
      assert hd(order_items).price == product1.price
    end

    # New validation tests for input validation
    test "returns error for empty product list", %{user: user} do
      assert {:error, :validate_input, :empty_product_list, _} =
               Orders.create_order(user.id, [])
    end

    test "returns error for nil product list", %{user: user} do
      assert {:error, :validate_input, :empty_product_list, _} =
               Orders.create_order(user.id, nil)
    end

    test "returns error for non-list product_ids", %{user: user} do
      assert {:error, :validate_input, :invalid_product_list, _} =
               Orders.create_order(user.id, "not-a-list")
    end

    test "returns error for duplicate products in request", %{user: user, product1: product1} do
      # Same product ID twice
      product_ids = [product1.id, product1.id]

      assert {:error, :validate_input, :duplicate_products_in_request, _} =
               Orders.create_order(user.id, product_ids)
    end

    test "transaction rolls back on validation failure", %{user: user, product1: product1} do
      # Mock a failure by trying to purchase already owned product
      {:ok, order} =
        Repo.insert(%Order{user_id: user.id, total: Decimal.new("10.00")})

      Repo.insert(%UserProduct{user_id: user.id, product_id: product1.id, order_id: order.id})

      initial_orders_count = Repo.aggregate(Order, :count)
      initial_order_items_count = Repo.aggregate(OrderItem, :count)
      initial_user_products_count = Repo.aggregate(UserProduct, :count)
      initial_balance = user.balance

      assert {:error, :validate_products, :products_already_purchased, _} =
               Orders.create_order(user.id, [product1.id])

      # Verify no changes were made
      assert Repo.aggregate(Order, :count) == initial_orders_count
      assert Repo.aggregate(OrderItem, :count) == initial_order_items_count
      assert Repo.aggregate(UserProduct, :count) == initial_user_products_count

      updated_user = Repo.get(User, user.id)
      assert updated_user.balance == initial_balance
    end
  end

  describe "get_order_with_items/1" do
    setup %{user: user, product1: product1, product2: product2} do
      {:ok, order} = Repo.insert(%Order{user_id: user.id, total: Decimal.new("30.00")})

      {:ok, _} =
        Repo.insert(%OrderItem{
          order_id: order.id,
          product_id: product1.id,
          price: product1.price
        })

      {:ok, _} =
        Repo.insert(%OrderItem{
          order_id: order.id,
          product_id: product2.id,
          price: product2.price
        })

      %{order: order}
    end

    test "returns order with preloaded items and products", %{
      order: order,
      product1: product1,
      product2: product2
    } do
      fetched_order = Orders.get_order_with_items(order.id)

      assert fetched_order.id == order.id
      assert fetched_order.total == Decimal.new("30.00")
      assert length(fetched_order.order_items) == 2

      # Verify products are preloaded
      order_item_product_ids = Enum.map(fetched_order.order_items, & &1.product.id)
      assert product1.id in order_item_product_ids
      assert product2.id in order_item_product_ids

      # Verify prices are preserved
      prices = Enum.map(fetched_order.order_items, & &1.price)
      assert product1.price in prices
      assert product2.price in prices
    end

    test "returns nil when order doesn't exist" do
      fake_uuid = Ecto.UUID.generate()
      assert Orders.get_order_with_items(fake_uuid) == nil
    end

    test "returns order with empty items list when no items", %{user: user} do
      {:ok, empty_order} = Repo.insert(%Order{user_id: user.id, total: Decimal.new("1.00")})

      fetched_order = Orders.get_order_with_items(empty_order.id)

      assert fetched_order.id == empty_order.id
      assert fetched_order.order_items == []
    end
  end
end

defmodule Backend.UsersTest do
  use Backend.DataCase, async: true

  alias Backend.Users
  alias Backend.Users.UserProduct
  alias Backend.Products.Product

  describe "register_user/1" do
    test "creates a user with valid attributes" do
      attrs = %{
        username: "testuser",
        email: "test@example.com",
        password: "Password123!"
      }

      assert {:ok, user} = Users.register_user(attrs)
      assert user.username == "testuser"
      assert user.email == "test@example.com"
      assert user.balance == Decimal.new("1000.00")
      assert Bcrypt.verify_pass("Password123!", user.password_hash)
    end

    test "returns error with invalid attributes" do
      attrs = %{username: "", email: "", password: "123"}

      assert {:error, changeset} = Users.register_user(attrs)
      assert %{username: ["can't be blank"]} = errors_on(changeset)
      assert %{email: ["can't be blank"]} = errors_on(changeset)
      errors = errors_on(changeset)
      assert "should be at least 6 character(s)" in errors.password
    end

    test "returns error with duplicate username" do
      attrs = %{username: "testuser", email: "test@example.com", password: "Password123!"}

      assert {:ok, _user} = Users.register_user(attrs)
      attrs2 = %{username: "testuser", email: "test2@example.com", password: "Password123!"}
      assert {:error, changeset} = Users.register_user(attrs2)
      assert %{username: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "authenticate_user/2" do
    setup do
      {:ok, user} =
        Users.register_user(%{
          username: "testuser",
          email: "test@example.com",
          password: "Password123!"
        })

      %{user: user}
    end

    test "authenticates user with valid credentials", %{user: user} do
      assert {:ok, authenticated_user} = Users.authenticate_user("testuser", "Password123!")
      assert authenticated_user.id == user.id
    end

    test "returns error with invalid username" do
      assert {:error, :invalid_credentials} =
               Users.authenticate_user("nonexistent", "Password123!")
    end

    test "returns error with invalid password", %{user: _user} do
      assert {:error, :invalid_credentials} =
               Users.authenticate_user("testuser", "WrongPassword!")
    end
  end

  describe "get_user/1" do
    test "returns user when exists" do
      {:ok, user} =
        Users.register_user(%{
          username: "testuser",
          email: "test@example.com",
          password: "Password123!"
        })

      assert fetched_user = Users.get_user(user.id)
      assert fetched_user.id == user.id
      assert fetched_user.username == "testuser"
    end

    test "returns nil when user doesn't exist" do
      fake_uuid = "00000000-0000-0000-0000-000000000000"
      assert Users.get_user(fake_uuid) == nil
    end
  end

  describe "get_user_with_products/1" do
    setup do
      {:ok, user} =
        Users.register_user(%{
          username: "testuser",
          email: "test@example.com",
          password: "Password123!"
        })

      {:ok, product} =
        Repo.insert(%Product{id: "product1", name: "Test Product", price: Decimal.new("10.00")})

      {:ok, order} =
        Repo.insert(%Backend.Orders.Order{user_id: user.id, total: Decimal.new("10.00")})

      Repo.insert(%UserProduct{user_id: user.id, product_id: product.id, order_id: order.id})

      %{user: user, product: product, order: order}
    end

    test "returns user with preloaded products", %{user: user} do
      fetched_user = Users.get_user_with_products(user.id)

      assert fetched_user.id == user.id
      assert length(fetched_user.user_products) == 1
    end

    test "returns nil when user doesn't exist" do
      fake_uuid = "00000000-0000-0000-0000-000000000000"
      assert Users.get_user_with_products(fake_uuid) == nil
    end
  end

  describe "get_user_by_username/1" do
    test "returns existing user by username" do
      {:ok, user} =
        Users.register_user(%{
          username: "testuser",
          email: "test@example.com",
          password: "Password123!"
        })

      assert {:ok, fetched_user} = Users.get_user_by_username("testuser")
      assert fetched_user.id == user.id
      assert fetched_user.username == "testuser"
    end

    test "creates new user when doesn't exist" do
      assert {:ok, user} = Users.get_user_by_username("newuser")
      assert user.username == "newuser"
      assert user.balance == Decimal.new("1000.00")
    end
  end

  describe "update_user_balance/2" do
    setup do
      {:ok, user} =
        Users.register_user(%{
          username: "testuser",
          email: "test@example.com",
          password: "Password123!"
        })

      %{user: user}
    end

    test "updates user balance successfully", %{user: user} do
      new_balance = Decimal.new("50.00")

      assert {:ok, updated_user} = Users.update_user_balance(user, new_balance)
      assert updated_user.balance == new_balance
    end

    test "returns error with invalid balance", %{user: user} do
      assert {:error, changeset} = Users.update_user_balance(user, "invalid")
      assert %{balance: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "get_user_product_ids/1" do
    setup do
      {:ok, user} =
        Users.register_user(%{
          username: "testuser",
          email: "test@example.com",
          password: "Password123!"
        })

      {:ok, product1} =
        Repo.insert(%Product{id: "product1", name: "Product 1", price: Decimal.new("10.00")})

      {:ok, product2} =
        Repo.insert(%Product{id: "product2", name: "Product 2", price: Decimal.new("20.00")})

      {:ok, order1} =
        Repo.insert(%Backend.Orders.Order{user_id: user.id, total: Decimal.new("10.00")})

      {:ok, order2} =
        Repo.insert(%Backend.Orders.Order{user_id: user.id, total: Decimal.new("20.00")})

      Repo.insert(%UserProduct{user_id: user.id, product_id: product1.id, order_id: order1.id})
      Repo.insert(%UserProduct{user_id: user.id, product_id: product2.id, order_id: order2.id})

      %{user: user, product1: product1, product2: product2, order1: order1, order2: order2}
    end

    test "returns list of product IDs for user", %{
      user: user,
      product1: product1,
      product2: product2
    } do
      product_ids = Users.get_user_product_ids(user)

      assert length(product_ids) == 2
      assert product1.id in product_ids
      assert product2.id in product_ids
    end

    test "returns empty list when user has no products" do
      {:ok, user} =
        Users.register_user(%{
          username: "emptyuser",
          email: "empty@example.com",
          password: "Password123!"
        })

      assert Users.get_user_product_ids(user) == []
    end
  end

  describe "add_user_products/3" do
    setup do
      {:ok, user} =
        Users.register_user(%{
          username: "testuser",
          email: "test@example.com",
          password: "Password123!"
        })

      {:ok, product1} =
        Repo.insert(%Product{id: "product1", name: "Product 1", price: Decimal.new("10.00")})

      {:ok, product2} =
        Repo.insert(%Product{id: "product2", name: "Product 2", price: Decimal.new("20.00")})

      %{user: user, product1: product1, product2: product2}
    end

    test "adds multiple products to user", %{user: user, product1: product1, product2: product2} do
      product_ids = [product1.id, product2.id]

      {:ok, order} =
        Repo.insert(%Backend.Orders.Order{user_id: user.id, total: Decimal.new("30.00")})

      {count, nil} = Users.add_user_products(user.id, product_ids, order.id)
      assert count == 2

      user_products = Repo.all(UserProduct)
      assert length(user_products) == 2

      assert Enum.all?(user_products, fn up ->
               up.user_id == user.id && up.order_id == order.id && up.product_id in product_ids
             end)
    end

    test "handles empty product list", %{user: user} do
      {:ok, order} =
        Repo.insert(%Backend.Orders.Order{user_id: user.id, total: Decimal.new("1.00")})

      {count, nil} = Users.add_user_products(user.id, [], order.id)
      assert count == 0

      assert Repo.all(UserProduct) == []
    end
  end
end

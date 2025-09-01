defmodule BackendWeb.AuthControllerTest do
  use BackendWeb.ConnCase, async: true

  alias Backend.{Users, Guardian}

  describe "POST /api/v1/auth/register" do
    test "registers a new user successfully", %{conn: conn} do
      user_params = %{
        "username" => "johndoe",
        "email" => "john@example.com",
        "password" => "SecurePass123!"
      }

      conn = post(conn, ~p"/api/v1/auth/register", user_params)

      assert %{
               "username" => "johndoe",
               "email" => "john@example.com",
               "token" => token
             } = json_response(conn, 201)

      # Verify token is valid
      assert {:ok, _claims} = Guardian.decode_and_verify(token)
    end

    test "returns error for invalid user data", %{conn: conn} do
      invalid_params = %{
        "username" => "",
        "email" => "invalid-email",
        "password" => "weak"
      }

      conn = post(conn, ~p"/api/v1/auth/register", invalid_params)

      assert %{
               "error" => "registration_failed",
               "message" => "User registration failed",
               "details" => details
             } = json_response(conn, 400)

      assert is_map(details)
      # Should have validation errors
      assert Map.has_key?(details, "username") or
               Map.has_key?(details, "email") or
               Map.has_key?(details, "password")
    end

    test "returns error for duplicate username", %{conn: conn} do
      # Create a user first
      {:ok, _user} =
        Users.register_user(%{
          username: "johndoe",
          email: "john@example.com",
          password: "SecurePass123!"
        })

      # Try to create another user with same username
      duplicate_params = %{
        "username" => "johndoe",
        "email" => "john2@example.com",
        "password" => "SecurePass123!"
      }

      conn = post(conn, ~p"/api/v1/auth/register", duplicate_params)

      assert %{
               "error" => "registration_failed",
               "details" => details
             } = json_response(conn, 400)

      assert Map.has_key?(details, "username")
    end

    test "returns error for duplicate email", %{conn: conn} do
      # Create a user first
      {:ok, _user} =
        Users.register_user(%{
          username: "johndoe",
          email: "john@example.com",
          password: "SecurePass123!"
        })

      # Try to create another user with same email
      duplicate_params = %{
        "username" => "janedoe",
        "email" => "john@example.com",
        "password" => "SecurePass123!"
      }

      conn = post(conn, ~p"/api/v1/auth/register", duplicate_params)

      assert %{
               "error" => "registration_failed",
               "details" => details
             } = json_response(conn, 400)

      assert Map.has_key?(details, "email")
    end
  end

  describe "POST /api/v1/auth/login" do
    setup do
      {:ok, user} =
        Users.register_user(%{
          username: "johndoe",
          email: "john@example.com",
          password: "SecurePass123!"
        })

      # Create some products
      products = create_test_products()
      # Pattern match to get first product
      [netflix | _] = products

      # Create a proper order first
      {:ok, %{order: _order}} = Backend.Orders.create_order(user.id, [netflix.id])

      %{user: user, products: products}
    end

    test "logs in user with valid credentials", %{conn: conn} do
      login_params = %{
        "username" => "johndoe",
        "password" => "SecurePass123!"
      }

      conn = post(conn, ~p"/api/v1/auth/login", login_params)

      assert %{
               "username" => "johndoe",
               "balance" => _balance,
               "product_ids" => product_ids,
               "token" => token
             } = json_response(conn, 200)

      assert is_binary(token)
      assert {:ok, _claims} = Guardian.decode_and_verify(token)
      assert is_list(product_ids)
    end

    test "returns error for invalid username", %{conn: conn} do
      login_params = %{
        "username" => "nonexistent",
        "password" => "SecurePass123!"
      }

      conn = post(conn, ~p"/api/v1/auth/login", login_params)

      assert %{
               "error" => "invalid_credentials",
               "message" => "Invalid username or password"
             } = json_response(conn, 401)
    end

    test "returns error for invalid password", %{conn: conn} do
      login_params = %{
        "username" => "johndoe",
        "password" => "WrongPassword"
      }

      conn = post(conn, ~p"/api/v1/auth/login", login_params)

      assert %{
               "error" => "invalid_credentials",
               "message" => "Invalid username or password"
             } = json_response(conn, 401)
    end

    test "returns user's product_ids on login", %{conn: conn, products: products} do
      login_params = %{
        "username" => "johndoe",
        "password" => "SecurePass123!"
      }

      conn = post(conn, ~p"/api/v1/auth/login", login_params)

      assert %{
               "product_ids" => product_ids
             } = json_response(conn, 200)

      # User should have the netflix product UUID from setup
      [netflix | _] = products
      assert netflix.id in product_ids
    end
  end

  describe "POST /api/v1/auth/refresh" do
    setup do
      {:ok, user} =
        Users.register_user(%{
          username: "johndoe",
          email: "john@example.com",
          password: "SecurePass123!"
        })

      {:ok, token, _claims} = Guardian.encode_and_sign(user)

      %{user: user, token: token}
    end

    test "refreshes token for authenticated user", %{conn: conn, token: old_token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{old_token}")
        |> post(~p"/api/v1/auth/refresh")

      assert %{"token" => new_token} = json_response(conn, 200)

      # Should get a new token
      assert new_token != old_token
      assert {:ok, _claims} = Guardian.decode_and_verify(new_token)
    end

    test "returns error for unauthenticated request", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/auth/refresh")

      assert json_response(conn, 401)
    end

    test "returns error for invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid-token")
        |> post(~p"/api/v1/auth/refresh")

      assert json_response(conn, 401)
    end
  end

  describe "POST /api/v1/auth/logout" do
    setup do
      {:ok, user} =
        Users.register_user(%{
          username: "johndoe",
          email: "john@example.com",
          password: "SecurePass123!"
        })

      {:ok, token, _claims} = Guardian.encode_and_sign(user)

      %{user: user, token: token}
    end

    test "logs out authenticated user", %{conn: conn, token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/v1/auth/logout")

      assert %{"message" => "Logged out successfully"} = json_response(conn, 200)
    end

    test "returns error for unauthenticated request", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/auth/logout")

      assert json_response(conn, 401)
    end

    test "returns error for invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid-token")
        |> post(~p"/api/v1/auth/logout")

      assert json_response(conn, 401)
    end
  end

  # Test the private function indirectly through validation errors
  describe "error formatting" do
    test "formats changeset errors correctly", %{conn: conn} do
      # This will trigger validation errors and test format_changeset_errors
      invalid_params = %{
        "username" => "",
        "email" => "not-an-email",
        # Too short
        "password" => "123"
      }

      conn = post(conn, ~p"/api/v1/auth/register", invalid_params)

      assert %{
               "error" => "registration_failed",
               "details" => details
             } = json_response(conn, 400)

      # Should be a map with string keys and string values
      assert is_map(details)

      # All values should be lists of strings (error messages)
      for {_field, messages} <- details do
        assert is_list(messages)
        assert Enum.all?(messages, &is_binary/1)
      end
    end
  end

  # Integration test to ensure everything works together
  describe "authentication flow" do
    test "complete registration -> login -> refresh -> logout flow", %{conn: conn} do
      # 1. Register
      user_params = %{
        "username" => "johndoe",
        "email" => "john@example.com",
        "password" => "SecurePass123!"
      }

      conn1 = post(conn, ~p"/api/v1/auth/register", user_params)
      assert %{"token" => _register_token} = json_response(conn1, 201)

      # 2. Login (get new token)
      login_params = %{
        "username" => "johndoe",
        "password" => "SecurePass123!"
      }

      conn2 = post(conn, ~p"/api/v1/auth/login", login_params)
      assert %{"token" => login_token} = json_response(conn2, 200)

      # 3. Refresh token
      conn3 =
        conn
        |> put_req_header("authorization", "Bearer #{login_token}")
        |> post(~p"/api/v1/auth/refresh")

      assert %{"token" => refresh_token} = json_response(conn3, 200)
      assert refresh_token != login_token

      # 4. Logout
      conn4 =
        conn
        |> put_req_header("authorization", "Bearer #{refresh_token}")
        |> post(~p"/api/v1/auth/logout")

      assert %{"message" => "Logged out successfully"} = json_response(conn4, 200)
    end
  end

  # Helper function to create test products
  defp create_test_products do
    alias Backend.Products.Product
    alias Backend.Repo

    products = [
      %{name: "netflix", description: "Netflix", price: Decimal.new("75.99")},
      %{name: "spotify", description: "Spotify", price: Decimal.new("45.99")}
    ]

    # Return the inserted products, not :ok
    Enum.map(products, fn attrs ->
      %Product{}
      |> Product.changeset(attrs)
      |> Repo.insert!()
    end)
  end
end

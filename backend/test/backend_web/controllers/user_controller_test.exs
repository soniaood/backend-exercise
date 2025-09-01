defmodule BackendWeb.UserControllerTest do
  use BackendWeb.ConnCase, async: true

  alias Backend.{Users, Guardian}

  describe "GET /api/v1/users/me (authenticated endpoint)" do
    setup do
      {:ok, user} =
        Users.register_user(%{
          username: "johndoe",
          email: "john@example.com",
          password: "SecurePass123!"
        })

      {:ok, token, _claims} = Guardian.encode_and_sign(user)
      create_test_products()

      %{user: user, token: token}
    end

    test "returns current user info successfully", %{conn: conn, token: token, user: _user} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/v1/users/me")

      assert %{
               "username" => "johndoe",
               "email" => "john@example.com",
               "balance" => balance,
               "product_ids" => product_ids
             } = json_response(conn, 200)

      assert is_binary(balance) or is_number(balance)
      assert is_list(product_ids)
      assert product_ids == []
    end

    test "returns user with purchased products", %{conn: conn, token: token} do
      # Get products first and use UUIDs for V1 API
      products = create_test_products()
      [netflix, spotify | _] = products

      # Create order using V1 endpoint with UUIDs
      order_params = %{
        "items" => [netflix.id, spotify.id]
      }

      order_conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/v1/orders", order_params)

      # Check that order was created successfully
      assert json_response(order_conn, 200)

      # Now get user info
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/v1/users/me")

      assert %{
               "product_ids" => product_ids
             } = json_response(conn, 200)

      # Should have both product UUIDs
      assert length(product_ids) >= 2,
             "Expected at least 2 products, got: #{inspect(product_ids)}"

      assert netflix.id in product_ids,
             "Netflix ID #{netflix.id} not found in #{inspect(product_ids)}"

      assert spotify.id in product_ids,
             "Spotify ID #{spotify.id} not found in #{inspect(product_ids)}"
    end

    test "returns error for missing token", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/users/me")

      assert %{
               "error" => _error,
               "message" => "Authentication required"
             } = json_response(conn, 401)
    end

    test "returns error for invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid-token")
        |> get(~p"/api/v1/users/me")

      assert json_response(conn, 401)
    end

    test "returns error for expired token", %{conn: conn, user: user} do
      # Create an expired token
      {:ok, old_token, _claims} = Guardian.encode_and_sign(user, %{}, ttl: {-1, :second})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{old_token}")
        |> get(~p"/api/v1/users/me")

      assert json_response(conn, 401)
    end
  end

  describe "GET /api/users/:username (legacy endpoint)" do
    test "creates new user when username doesn't exist", %{conn: conn} do
      conn = get(conn, ~p"/api/users/newuser")

      assert %{
               "user" => %{
                 "user_id" => "newuser",
                 "data" => %{
                   "balance" => balance,
                   "product_ids" => []
                 }
               }
             } = json_response(conn, 200)

      # Balance should be string representation of Decimal
      assert is_binary(balance) or is_number(balance)

      # Verify deprecation header
      assert get_resp_header(conn, "x-deprecated") == [
               "Use GET /api/users/me with authentication"
             ]
    end

    test "returns existing user when username exists", %{conn: conn} do
      # Create user via legacy method first
      get(conn, ~p"/api/users/existinguser")

      # Get the same user again
      conn = get(conn, ~p"/api/users/existinguser")

      assert %{
               "user" => %{
                 "user_id" => "existinguser",
                 "data" => %{
                   "balance" => balance,
                   "product_ids" => []
                 }
               }
             } = json_response(conn, 200)

      assert is_binary(balance) or is_number(balance)

      assert get_resp_header(conn, "x-deprecated") == [
               "Use GET /api/users/me with authentication"
             ]
    end

    test "returns user with purchased products", %{conn: conn} do
      # Create user and buy some products via legacy endpoint
      get(conn, ~p"/api/users/shopperuser")
      create_test_products()

      # Buy products via legacy endpoint (uses product names)
      order_params = %{
        "order" => %{
          "items" => ["netflix"],
          "user_id" => "shopperuser"
        }
      }

      post(conn, ~p"/api/orders", order_params)

      # Now get user info
      conn = get(conn, ~p"/api/users/shopperuser")

      assert %{
               "user" => %{
                 "user_id" => "shopperuser",
                 "data" => %{
                   "balance" => updated_balance,
                   "product_ids" => product_ids
                 }
               }
             } = json_response(conn, 200)

      # Balance should be reduced - it's a string representation
      balance_decimal =
        if is_binary(updated_balance),
          do: Decimal.new(updated_balance),
          else: Decimal.new("#{updated_balance}")

      assert Decimal.compare(balance_decimal, Decimal.new("1000.00")) == :lt

      # Should have netflix UUID, not name (legacy endpoint still returns UUIDs in product_ids)
      assert length(product_ids) == 1
      # The product_ids will be UUIDs, not names
      assert is_binary(hd(product_ids))
    end

    test "returns user with correct balance after multiple purchases", %{conn: conn} do
      create_test_products()

      # Create user
      get(conn, ~p"/api/users/buyeruser")

      # Buy multiple items via legacy endpoint
      order_params1 = %{
        "order" => %{
          # 75.99
          "items" => ["netflix"],
          "user_id" => "buyeruser"
        }
      }

      post(conn, ~p"/api/orders", order_params1)

      order_params2 = %{
        "order" => %{
          # 45.99
          "items" => ["spotify"],
          "user_id" => "buyeruser"
        }
      }

      post(conn, ~p"/api/orders", order_params2)

      # Check final balance
      conn = get(conn, ~p"/api/users/buyeruser")

      assert %{
               "user" => %{
                 "data" => %{
                   "balance" => final_balance,
                   "product_ids" => product_ids
                 }
               }
             } = json_response(conn, 200)

      # Balance should be 1000 - 75.99 - 45.99 = 878.02
      balance_decimal =
        if is_binary(final_balance),
          do: Decimal.new(final_balance),
          else: Decimal.new("#{final_balance}")

      expected_balance = Decimal.sub(Decimal.new("1000.00"), Decimal.new("121.98"))
      assert Decimal.equal?(balance_decimal, expected_balance)

      assert length(product_ids) == 2
    end

    test "handles special characters in username", %{conn: conn} do
      # Test with username containing allowed special characters
      conn = get(conn, ~p"/api/users/user_123")

      assert %{
               "user" => %{
                 "user_id" => "user_123",
                 "data" => %{
                   "balance" => balance,
                   "product_ids" => []
                 }
               }
             } = json_response(conn, 200)

      assert is_binary(balance) or is_number(balance)
    end
  end

  describe "response format validation" do
    test "modern endpoint has correct response structure", %{conn: conn} do
      {:ok, user} =
        Users.register_user(%{
          username: "formattest",
          email: "format@example.com",
          password: "SecurePass123!"
        })

      {:ok, token, _claims} = Guardian.encode_and_sign(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/v1/users/me")

      user_data = json_response(conn, 200)

      # Verify required fields are present (based on your controller)
      required_fields = ["username", "email", "balance", "product_ids"]

      for field <- required_fields do
        assert Map.has_key?(user_data, field), "Missing field: #{field}"
      end

      # Verify field types
      assert is_binary(user_data["username"])
      assert is_binary(user_data["email"])
      assert is_binary(user_data["balance"]) or is_number(user_data["balance"])
      assert is_list(user_data["product_ids"])
    end

    test "legacy endpoint has correct response structure", %{conn: conn} do
      conn = get(conn, ~p"/api/users/legacyformat")

      assert %{
               "user" => %{
                 "user_id" => user_id,
                 "data" => data
               }
             } = json_response(conn, 200)

      assert is_binary(user_id)
      assert is_map(data)

      # Verify data structure
      assert Map.has_key?(data, "balance")
      assert Map.has_key?(data, "product_ids")
      assert is_binary(data["balance"]) or is_number(data["balance"])
      assert is_list(data["product_ids"])
    end
  end

  describe "integration between endpoints" do
    test "legacy and modern endpoints return consistent user data", %{conn: conn} do
      # Create user via modern registration
      {:ok, user} =
        Users.register_user(%{
          username: "integration_test",
          email: "integration@example.com",
          password: "SecurePass123!"
        })

      {:ok, token, _claims} = Guardian.encode_and_sign(user)

      # Get user info via modern endpoint
      modern_conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/v1/users/me")

      modern_response = json_response(modern_conn, 200)

      # Get user info via legacy endpoint
      legacy_conn = get(conn, ~p"/api/users/integration_test")
      legacy_response = json_response(legacy_conn, 200)

      # Compare core data
      modern_user = modern_response
      legacy_user = legacy_response["user"]

      assert modern_user["username"] == legacy_user["user_id"]
      assert modern_user["balance"] == legacy_user["data"]["balance"]
      assert modern_user["product_ids"] == legacy_user["data"]["product_ids"]
    end
  end

  # Helper function to create test products and return them
  defp create_test_products do
    alias Backend.Products.Product
    alias Backend.Repo

    products = [
      %{name: "netflix", description: "Netflix Subscription", price: Decimal.new("75.99")},
      %{name: "spotify", description: "Spotify Premium", price: Decimal.new("45.99")},
      %{name: "gym", description: "Gym Membership", price: Decimal.new("120.00")}
    ]

    Enum.map(products, fn attrs ->
      case Repo.get_by(Product, name: attrs.name) do
        nil ->
          %Product{}
          |> Product.changeset(attrs)
          |> Repo.insert!()

        existing_product ->
          existing_product
      end
    end)
  end
end

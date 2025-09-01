defmodule BackendWeb.OrderControllerTest do
  use BackendWeb.ConnCase, async: true

  alias Backend.{Users, Guardian}

  describe "POST /api/orders (Frontend prototype - no authentication)" do
    setup do
      # Create user via legacy method
      {:ok, user} = Users.get_user_by_username("johndoe")
      create_test_products()
      %{user: user}
    end

    test "creates order successfully with valid data", %{conn: conn} do
      order_params = %{
        "order" => %{
          "items" => ["netflix", "spotify"],
          "user_id" => "johndoe"
        }
      }

      conn = post(conn, ~p"/api/orders", order_params)

      assert %{
               "order" => %{
                 "order_id" => order_id,
                 "data" => %{
                   "items" => items,
                   "total" => total
                 }
               }
             } = json_response(conn, 200)

      assert is_binary(order_id)
      assert is_list(items)
      assert length(items) == 2
      assert is_binary(total)

      # Verify items contain expected products
      product_ids = Enum.map(items, & &1["id"])
      assert "netflix" in product_ids
      assert "spotify" in product_ids
    end

    test "returns error for nonexistent products", %{conn: conn} do
      order_params = %{
        "order" => %{
          "items" => ["nonexistent-product"],
          "user_id" => "johndoe"
        }
      }

      conn = post(conn, ~p"/api/orders", order_params)

      assert %{
               "error" => "products_not_found",
               "message" => "One or more products were not found"
             } = json_response(conn, 400)
    end

    test "returns error for insufficient balance", %{conn: conn, user: user} do
      # Update user balance to be insufficient
      Users.update_user_balance(user, Decimal.new("50.00"))

      order_params = %{
        "order" => %{
          # Total > 50
          "items" => ["netflix", "spotify"],
          "user_id" => "johndoe"
        }
      }

      conn = post(conn, ~p"/api/orders", order_params)

      assert %{
               "error" => "insufficient_balance",
               "message" => "User balance is insufficient for this order"
             } = json_response(conn, 400)
    end

    test "returns error for already purchased products", %{conn: conn} do
      # First, buy netflix
      order_params1 = %{
        "order" => %{
          "items" => ["netflix"],
          "user_id" => "johndoe"
        }
      }

      post(conn, ~p"/api/orders", order_params1)

      # Try to buy netflix again
      order_params2 = %{
        "order" => %{
          "items" => ["netflix"],
          "user_id" => "johndoe"
        }
      }

      conn = post(conn, ~p"/api/orders", order_params2)

      assert %{
               "error" => "products_already_purchased",
               "message" => "User has already purchased one or more of these products"
             } = json_response(conn, 400)
    end
  end

  describe "POST /api/v1/orders (authenticated)" do
    setup do
      {:ok, user} =
        Users.register_user(%{
          username: "johndoe",
          email: "john@example.com",
          password: "SecurePass123!"
        })

      {:ok, token, _claims} = Guardian.encode_and_sign(user)
      products = create_test_products()

      %{user: user, token: token, products: products}
    end

    test "creates order successfully with JWT authentication", %{
      conn: conn,
      token: token,
      products: products
    } do
      # Use actual product UUIDs for V1 API
      [netflix, spotify | _] = products

      order_params = %{
        "items" => [netflix.id, spotify.id]
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/v1/orders", order_params)

      assert %{
               "id" => order_id,
               "items" => items,
               "total" => total,
               "created_at" => created_at
             } = json_response(conn, 200)

      assert is_binary(order_id)
      assert is_list(items)
      assert length(items) == 2
      assert is_binary(created_at)
      assert total == "121.98"

      # Verify items contain expected products
      product_names = Enum.map(items, & &1["name"])
      assert "netflix" in product_names
      assert "spotify" in product_names

      Enum.each(items, fn item ->
        assert is_binary(item["id"])
        assert is_binary(item["name"])
        assert is_binary(item["description"])
        assert item["price"] != nil
      end)
    end

    test "returns error for unauthenticated request", %{conn: conn, products: products} do
      [netflix | _] = products

      order_params = %{
        "items" => [netflix.id]
      }

      conn = post(conn, ~p"/api/v1/orders", order_params)

      assert %{
               "error" => _error,
               "message" => "Authentication required"
             } = json_response(conn, 401)
    end

    test "returns error for invalid token", %{conn: conn, products: products} do
      [netflix | _] = products

      order_params = %{
        "items" => [netflix.id]
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid-token")
        |> post(~p"/api/v1/orders", order_params)

      assert json_response(conn, 401)
    end

    test "authenticated endpoint follows same business rules as legacy", %{
      conn: conn,
      token: token
    } do
      # Test insufficient balance with authenticated endpoint
      expensive_products = create_expensive_products()
      [premium, deluxe | _] = expensive_products

      order_params = %{
        "items" => [premium.id, deluxe.id]
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/v1/orders", order_params)

      assert %{
               "error" => "insufficient_balance",
               "message" => "User balance is insufficient for this order"
             } = json_response(conn, 400)
    end
  end

  describe "smart routing logic" do
    setup do
      {:ok, user} =
        Users.register_user(%{
          username: "johndoe",
          email: "john@example.com",
          password: "SecurePass123!"
        })

      {:ok, token, _claims} = Guardian.encode_and_sign(user)
      products = create_test_products()

      %{user: user, token: token, products: products}
    end

    test "handles unauthenticated request vs authenticated request differently", %{
      conn: conn,
      token: token,
      products: products
    } do
      [netflix | _] = products

      order_params = %{
        "items" => [netflix.id]
      }

      # Unauthenticated request - should fail with 401
      conn1 = post(conn, ~p"/api/v1/orders", order_params)
      assert json_response(conn1, 401)

      # Authenticated request - should work
      conn2 =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/v1/orders", order_params)

      assert json_response(conn2, 200)
    end
  end

  # Helper functions
  defp create_test_products do
    alias Backend.Products.Product
    alias Backend.Repo

    products = [
      %{name: "netflix", description: "Netflix", price: Decimal.new("75.99")},
      %{name: "spotify", description: "Spotify", price: Decimal.new("45.99")},
      %{name: "gym", description: "Gym Membership", price: Decimal.new("120.00")}
    ]

    # Return the created products so tests can access their UUIDs
    Enum.map(products, fn attrs ->
      %Product{}
      |> Product.changeset(attrs)
      |> Repo.insert!(on_conflict: :nothing)
    end)
  end

  defp create_expensive_products do
    alias Backend.Products.Product
    alias Backend.Repo

    products = [
      %{name: "premium", description: "Premium Service", price: Decimal.new("500.00")},
      %{name: "deluxe", description: "Deluxe Package", price: Decimal.new("600.00")}
    ]

    # Return the created products so tests can access their UUIDs
    Enum.map(products, fn attrs ->
      %Product{}
      |> Product.changeset(attrs)
      |> Repo.insert!(on_conflict: :nothing)
    end)
  end
end

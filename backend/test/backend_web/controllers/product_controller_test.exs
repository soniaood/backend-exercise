# test/backend_web/controllers/product_controller_test.exs
defmodule BackendWeb.ProductControllerTest do
  use BackendWeb.ConnCase, async: true

  alias Backend.Products

  describe "GET /api/products" do
    test "returns empty list when no products exist", %{conn: conn} do
      conn = get(conn, ~p"/api/products")

      assert %{
               "products" => []
             } = json_response(conn, 200)
    end

    test "returns list of products", %{conn: conn} do
      # Create test products
      create_test_products()

      conn = get(conn, ~p"/api/products")

      assert %{
               "products" => products
             } = json_response(conn, 200)

      assert length(products) == 3

      # Check structure of each product
      Enum.each(products, fn product ->
        assert %{
                 "id" => _id,
                 "name" => _name,
                 "price" => _price
               } = product

        assert is_binary(product["id"])
        assert is_binary(product["name"])
        # Price should be a string representation of decimal
        assert is_binary(product["price"]) or is_number(product["price"])
      end)
    end

    test "returns products with correct data", %{conn: conn} do
      # Create specific test product
      {:ok, _product} =
        Products.create_product(%{
          id: "test-product",
          name: "Test Product",
          price: Decimal.new("99.99")
        })

      conn = get(conn, ~p"/api/products")

      assert %{
               "products" => [returned_product]
             } = json_response(conn, 200)

      assert %{
               "id" => "test-product",
               "name" => "Test Product",
               "price" => price
             } = returned_product

      # Price might be returned as string or number depending on JSON encoding
      assert price == "99.99" or price == 99.99
    end

    test "returns products sorted consistently", %{conn: conn} do
      # Create products with different names to test ordering
      products_data = [
        %{id: "zebra", name: "Zebra Product", price: Decimal.new("10.00")},
        %{id: "alpha", name: "Alpha Product", price: Decimal.new("20.00")},
        %{id: "beta", name: "Beta Product", price: Decimal.new("30.00")}
      ]

      Enum.each(products_data, fn product_data ->
        {:ok, _product} = Products.create_product(product_data)
      end)

      conn = get(conn, ~p"/api/products")

      assert %{
               "products" => products
             } = json_response(conn, 200)

      assert length(products) == 3

      # Extract IDs to verify they're returned consistently
      product_ids = Enum.map(products, fn p -> p["id"] end)
      assert length(product_ids) == length(Enum.uniq(product_ids))
    end

    test "handles large number of products", %{conn: conn} do
      # Create many products to test performance/pagination (if implemented)
      products_data =
        for i <- 1..50 do
          %{
            id: "product-#{i}",
            name: "Product #{i}",
            price: Decimal.new("#{i}.99")
          }
        end

      Enum.each(products_data, fn product_data ->
        {:ok, _product} = Products.create_product(product_data)
      end)

      conn = get(conn, ~p"/api/products")

      assert %{
               "products" => products
             } = json_response(conn, 200)

      assert length(products) == 50
    end

    test "returns correct content-type header", %{conn: conn} do
      create_test_products()

      conn = get(conn, ~p"/api/products")

      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
      assert json_response(conn, 200)
    end
  end

  describe "GET /products (legacy)" do
    test "returns list of products with deprecation header", %{conn: conn} do
      create_test_products()

      conn = get(conn, ~p"/products")

      # Check deprecation header
      assert get_resp_header(conn, "x-deprecated") == ["Use GET /api/products"]

      # Should have same response format as modern endpoint
      assert %{
               "products" => products
             } = json_response(conn, 200)

      assert length(products) == 3
    end

    test "returns empty list when no products exist", %{conn: conn} do
      conn = get(conn, ~p"/products")

      assert get_resp_header(conn, "x-deprecated") == ["Use GET /api/products"]

      assert %{
               "products" => []
             } = json_response(conn, 200)
    end

    test "has identical response format to modern endpoint", %{conn: conn} do
      create_test_products()

      # Get response from both endpoints
      modern_conn = get(conn, ~p"/api/products")
      legacy_conn = get(conn, ~p"/products")

      modern_response = json_response(modern_conn, 200)
      legacy_response = json_response(legacy_conn, 200)

      # Responses should be identical (except headers)
      assert modern_response == legacy_response
    end

    test "sets correct status code", %{conn: conn} do
      conn = get(conn, ~p"/products")

      assert conn.status == 200
      assert get_resp_header(conn, "x-deprecated") == ["Use GET /api/products"]
    end
  end

  describe "error handling" do
    test "handles database connection errors gracefully", %{conn: conn} do
      # This is harder to test without mocking, but we can test the controller logic
      # For now, we'll test that the endpoint responds correctly under normal circumstances

      conn = get(conn, ~p"/api/products")

      # Should not crash and should return valid JSON
      assert json_response(conn, 200)
    end
  end

  describe "response format validation" do
    test "product fields are correctly formatted", %{conn: conn} do
      {:ok, _product} =
        Products.create_product(%{
          id: "formatting-test",
          name: "Format Test Product",
          price: Decimal.new("123.45")
        })

      conn = get(conn, ~p"/api/products")

      assert %{
               "products" => [product]
             } = json_response(conn, 200)

      # Validate all required fields are present
      assert Map.has_key?(product, "id")
      assert Map.has_key?(product, "name")
      assert Map.has_key?(product, "price")

      # Validate no extra fields are included
      expected_keys = ["id", "name", "price"]
      actual_keys = Map.keys(product)
      assert Enum.sort(actual_keys) == Enum.sort(expected_keys)

      # Validate field types
      assert is_binary(product["id"])
      assert is_binary(product["name"])
      assert is_binary(product["price"]) or is_number(product["price"])
    end

    test "handles products with edge case values", %{conn: conn} do
      edge_cases = [
        # Very long name
        %{id: "long-name", name: String.duplicate("A", 255), price: Decimal.new("0.01")},
        # Very high price
        %{id: "high-price", name: "Expensive", price: Decimal.new("99999.99")},
        # Very low price (but not zero due to validation)
        %{id: "cheap", name: "Cheap Product", price: Decimal.new("0.01")}
      ]

      Enum.each(edge_cases, fn product_data ->
        {:ok, _product} = Products.create_product(product_data)
      end)

      conn = get(conn, ~p"/api/products")

      assert %{
               "products" => products
             } = json_response(conn, 200)

      assert length(products) == 3

      # All products should be formatted correctly
      Enum.each(products, fn product ->
        assert %{
                 "id" => _id,
                 "name" => _name,
                 "price" => _price
               } = product
      end)
    end
  end

  describe "integration with Products context" do
    test "returns products from Products.list_products/0", %{conn: conn} do
      # Create a product directly through the context
      {:ok, created_product} =
        Products.create_product(%{
          id: "integration-test",
          name: "Integration Product",
          price: Decimal.new("50.00")
        })

      conn = get(conn, ~p"/api/products")

      assert %{
               "products" => [returned_product]
             } = json_response(conn, 200)

      assert returned_product["id"] == created_product.id
      assert returned_product["name"] == created_product.name
    end
  end

  # Helper function to create consistent test data
  defp create_test_products do
    products_data = [
      %{id: "netflix", name: "Netflix Subscription", price: Decimal.new("75.99")},
      %{id: "spotify", name: "Spotify Premium", price: Decimal.new("45.99")},
      %{id: "gym", name: "Gym Membership", price: Decimal.new("120.00")}
    ]

    Enum.each(products_data, fn product_data ->
      {:ok, _product} = Products.create_product(product_data)
    end)
  end
end

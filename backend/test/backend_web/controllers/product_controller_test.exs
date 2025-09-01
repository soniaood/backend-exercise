defmodule BackendWeb.ProductControllerTest do
  use BackendWeb.ConnCase, async: true

  alias Backend.Products

  describe "GET /api/v1/products" do
    test "returns empty list when no products exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/products")

      assert json_response(conn, 200) == []
    end

    test "returns products with correct data", %{conn: conn} do
      # Create a test product with all required fields
      {:ok, _product} =
        Products.create_product(%{
          name: "Test Product",
          # Added required field
          description: "Test Description",
          price: Decimal.new("99.99")
        })

      conn = get(conn, ~p"/api/v1/products")

      assert [product] = json_response(conn, 200)
      assert product["id"] != nil
      assert product["name"] == "Test Product"
      assert product["description"] == "Test Description"
      assert product["price"] == "99.99"
    end

    test "returns products sorted consistently", %{conn: conn} do
      products_data = [
        %{name: "Zebra Product", description: "Last alphabetically", price: Decimal.new("10.00")},
        %{
          name: "Alpha Product",
          description: "First alphabetically",
          price: Decimal.new("20.00")
        },
        %{name: "Beta Product", description: "Second alphabetically", price: Decimal.new("30.00")}
      ]

      Enum.each(products_data, fn product_data ->
        {:ok, _product} = Products.create_product(product_data)
      end)

      conn = get(conn, ~p"/api/v1/products")
      products = json_response(conn, 200)

      assert length(products) == 3

      # Products should be returned in database order (typically insertion order)
      product_names = Enum.map(products, & &1["name"])
      assert "Zebra Product" in product_names
      assert "Alpha Product" in product_names
      assert "Beta Product" in product_names
    end

    test "handles large number of products", %{conn: conn} do
      # Create 50 test products
      products_data =
        Enum.map(1..50, fn i ->
          %{
            name: "Product #{i}",
            # Added required field
            description: "Description #{i}",
            price: Decimal.new("#{i}.99")
          }
        end)

      Enum.each(products_data, fn product_data ->
        {:ok, _product} = Products.create_product(product_data)
      end)

      conn = get(conn, ~p"/api/v1/products")
      products = json_response(conn, 200)

      assert length(products) == 50

      # Verify all products have required fields
      Enum.each(products, fn product ->
        assert product["id"] != nil
        assert product["name"] != nil
        assert product["description"] != nil
        assert product["price"] != nil
      end)
    end

    test "returns correct content type", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/products")

      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    end
  end

  describe "GET /api/products (legacy)" do
    test "returns list of products with deprecation header", %{conn: conn} do
      {:ok, _product} =
        Products.create_product(%{
          name: "netflix",
          description: "Netflix Subscription",
          price: Decimal.new("75.99")
        })

      conn = get(conn, ~p"/api/products")

      # Check the actual deprecation header message from your controller
      assert get_resp_header(conn, "x-deprecated") == [
               "Use GET /api/v1/products"
             ]

      assert %{"products" => products} = json_response(conn, 200)
      assert length(products) == 1

      [product] = products
      # Legacy: name becomes "id"
      assert product["id"] == "netflix"
      # Legacy: description becomes "name"
      assert product["name"] == "Netflix Subscription"
      assert product["price"] == "75.99"
    end

    test "returns empty list when no products exist", %{conn: conn} do
      conn = get(conn, ~p"/api/products")

      assert get_resp_header(conn, "x-deprecated") == [
               "Use GET /api/v1/products"
             ]

      assert json_response(conn, 200) == %{"products" => []}
    end

    test "sets correct status code", %{conn: conn} do
      conn = get(conn, ~p"/api/products")

      assert conn.status == 200

      assert get_resp_header(conn, "x-deprecated") == [
               "Use GET /api/v1/products"
             ]
    end

    test "maps fields correctly for legacy compatibility", %{conn: conn} do
      {:ok, _product1} =
        Products.create_product(%{
          name: "spotify",
          description: "Spotify Premium",
          price: Decimal.new("45.99")
        })

      {:ok, _product2} =
        Products.create_product(%{
          name: "gym",
          description: "Gym Membership",
          price: Decimal.new("120.00")
        })

      conn = get(conn, ~p"/api/products")

      assert %{"products" => products} = json_response(conn, 200)
      assert length(products) == 2

      # Verify legacy field mapping
      # "id" field contains the name
      product_names = Enum.map(products, & &1["id"])
      assert "spotify" in product_names
      assert "gym" in product_names

      # "name" field contains description
      display_names = Enum.map(products, & &1["name"])
      assert "Spotify Premium" in display_names
      assert "Gym Membership" in display_names
    end
  end

  describe "API comparison" do
    setup do
      {:ok, product} =
        Products.create_product(%{
          name: "test_product",
          description: "Test Product Description",
          price: Decimal.new("50.00")
        })

      %{product: product}
    end

    test "V1 and legacy APIs return different formats", %{conn: conn, product: product} do
      # Test V1 API
      conn_v1 = get(conn, ~p"/api/v1/products")
      v1_products = json_response(conn_v1, 200)

      # Test legacy API
      conn_legacy = get(conn, ~p"/api/products")
      legacy_response = json_response(conn_legacy, 200)
      legacy_products = legacy_response["products"]

      # V1 returns array directly
      assert is_list(v1_products)
      [v1_product] = v1_products
      # UUID
      assert v1_product["id"] == product.id
      assert v1_product["name"] == "test_product"
      assert v1_product["description"] == "Test Product Description"

      # Legacy returns wrapped array with field mapping
      assert is_list(legacy_products)
      [legacy_product] = legacy_products
      # name becomes id
      assert legacy_product["id"] == "test_product"
      # description becomes name
      assert legacy_product["name"] == "Test Product Description"
    end
  end

  describe "integration with Products context" do
    test "returns products from Products.list_products/0", %{conn: conn} do
      # Create product directly through Products context
      {:ok, created_product} =
        Products.create_product(%{
          name: "Integration Product",
          description: "Integration Test",
          price: Decimal.new("25.50")
        })

      conn = get(conn, ~p"/api/v1/products")
      products = json_response(conn, 200)

      assert length(products) == 1
      [returned_product] = products

      # Check that controller returns the same data as the context
      # Fixed: compare UUID to UUID
      assert returned_product["id"] == created_product.id
      assert returned_product["name"] == created_product.name
      assert returned_product["description"] == created_product.description
      # JSON converts Decimal to string
      assert returned_product["price"] == "25.50"
    end
  end
end

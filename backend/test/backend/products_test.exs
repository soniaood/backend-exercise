defmodule Backend.ProductsTest do
  use Backend.DataCase, async: true

  alias Backend.Products
  alias Backend.Products.Product

  describe "list_products/0" do
    setup do
      # Clear existing data for this test
      Repo.delete_all(Backend.Orders.OrderItem)
      Repo.delete_all(Backend.Users.UserProduct)
      Repo.delete_all(Backend.Orders.Order)
      Repo.delete_all(Backend.Users.User)
      Repo.delete_all(Product)
      :ok
    end

    test "returns all products" do
      {:ok, product1} =
        Repo.insert(%Product{name: "product1", description: "Product 1", price: Decimal.new("10.00")})

      {:ok, product2} =
        Repo.insert(%Product{name: "product2", description: "Product 2", price: Decimal.new("20.00")})

      products = Products.list_products()

      assert length(products) == 2
      product_ids = Enum.map(products, & &1.id)
      assert product1.id in product_ids
      assert product2.id in product_ids
    end

    test "returns empty list when no products exist" do
      assert Products.list_products() == []
    end
  end

  describe "get_products_by_ids/1" do
    setup do
      {:ok, product1} =
        Repo.insert(%Product{name: "product1", description: "Product 1", price: Decimal.new("10.00")})

      {:ok, product2} =
        Repo.insert(%Product{name: "product2", description: "Product 2", price: Decimal.new("20.00")})

      {:ok, product3} =
        Repo.insert(%Product{name: "product3", description: "Product 3", price: Decimal.new("30.00")})

      %{product1: product1, product2: product2, product3: product3}
    end

    test "returns products with matching IDs", %{
      product1: product1,
      product2: product2,
      product3: product3
    } do
      products = Products.get_products_by_ids([product1.id, product3.id])

      assert length(products) == 2
      product_ids = Enum.map(products, & &1.id)
      assert product1.id in product_ids
      assert product3.id in product_ids
      refute product2.id in product_ids
    end

    test "returns empty list when no matching IDs", %{product1: _product1} do
      fake_uuid1 = Ecto.UUID.generate()
      fake_uuid2 = Ecto.UUID.generate()
      products = Products.get_products_by_ids([fake_uuid1, fake_uuid2])
      assert products == []
    end

    test "returns empty list when given empty ID list" do
      products = Products.get_products_by_ids([])
      assert products == []
    end

    test "handles mix of existing and non-existing IDs", %{product1: product1} do
      fake_uuid = Ecto.UUID.generate()
      products = Products.get_products_by_ids([product1.id, fake_uuid])

      assert length(products) == 1
      assert hd(products).id == product1.id
    end
  end

  describe "get_products_by_names/1" do
    setup do
      {:ok, product1} =
        Repo.insert(%Product{name: "test_netflix", description: "Test Netflix", price: Decimal.new("75.99")})

      {:ok, product2} =
        Repo.insert(%Product{name: "test_spotify", description: "Test Spotify", price: Decimal.new("45.99")})

      {:ok, product3} =
        Repo.insert(%Product{name: "test_gym", description: "Test Gym", price: Decimal.new("120.00")})

      %{product1: product1, product2: product2, product3: product3}
    end

    test "returns products with matching names", %{
      product1: _product1,
      product2: _product2,
      product3: _product3
    } do
      products = Products.get_products_by_names(["test_netflix", "test_gym"])

      assert length(products) == 2
      product_names = Enum.map(products, & &1.name)
      assert "test_netflix" in product_names
      assert "test_gym" in product_names
      refute "test_spotify" in product_names
    end

    test "returns empty list when no matching names" do
      products = Products.get_products_by_names(["nonexistent1", "nonexistent2"])
      assert products == []
    end

    test "returns empty list when given empty name list" do
      products = Products.get_products_by_names([])
      assert products == []
    end

    test "handles mix of existing and non-existing names", %{product1: product1} do
      products = Products.get_products_by_names(["test_netflix", "nonexistent"])

      assert length(products) == 1
      assert hd(products).name == product1.name
    end
  end

  describe "get_product_by_name/1" do
    setup do
      {:ok, product} =
        Repo.insert(%Product{name: "test_product", description: "Test Product", price: Decimal.new("75.99")})

      %{product: product}
    end

    test "returns product with matching name", %{product: product} do
      found_product = Products.get_product_by_name("test_product")
      assert found_product.id == product.id
      assert found_product.name == "test_product"
    end

    test "returns nil when no matching name" do
      assert Products.get_product_by_name("nonexistent") == nil
    end
  end

  describe "create_product/1" do
    test "creates a product with valid attributes" do
      attrs = %{
        name: "new_product",
        description: "New Product",
        price: Decimal.new("25.99")
      }

      assert {:ok, product} = Products.create_product(attrs)
      assert is_binary(product.id)  # UUID is generated
      assert product.name == "new_product"  # name field contains identifier
      assert product.description == "New Product"  # description field contains display name
      assert product.price == Decimal.new("25.99")
    end

    test "returns error with invalid attributes" do
      attrs = %{name: "", description: "", price: "invalid"}

      assert {:error, changeset} = Products.create_product(attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
      assert %{description: ["can't be blank"]} = errors_on(changeset)
      assert %{price: ["is invalid"]} = errors_on(changeset)
    end

    test "returns error with missing required fields" do
      attrs = %{}

      assert {:error, changeset} = Products.create_product(attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
      assert %{description: ["can't be blank"]} = errors_on(changeset)
      assert %{price: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error with negative price" do
      attrs = %{
        name: "negative_product",
        description: "Product",
        price: Decimal.new("-10.00")
      }

      assert {:error, changeset} = Products.create_product(attrs)
      assert %{price: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "returns error with zero price" do
      attrs = %{
        name: "zero_product",
        description: "Product",
        price: Decimal.new("0.00")
      }

      assert {:error, changeset} = Products.create_product(attrs)
      assert %{price: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "creates product with minimum valid price" do
      attrs = %{
        name: "cheap_product",
        description: "Cheap Product",
        price: Decimal.new("0.01")
      }

      assert {:ok, product} = Products.create_product(attrs)
      assert product.price == Decimal.new("0.01")
    end
  end
end

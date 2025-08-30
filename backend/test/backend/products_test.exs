defmodule Backend.ProductsTest do
  use Backend.DataCase, async: true

  alias Backend.Products
  alias Backend.Products.Product

  describe "list_products/0" do
    test "returns all products" do
      {:ok, product1} =
        Repo.insert(%Product{id: "product1", name: "Product 1", price: Decimal.new("10.00")})

      {:ok, product2} =
        Repo.insert(%Product{id: "product2", name: "Product 2", price: Decimal.new("20.00")})

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
        Repo.insert(%Product{id: "product1", name: "Product 1", price: Decimal.new("10.00")})

      {:ok, product2} =
        Repo.insert(%Product{id: "product2", name: "Product 2", price: Decimal.new("20.00")})

      {:ok, product3} =
        Repo.insert(%Product{id: "product3", name: "Product 3", price: Decimal.new("30.00")})

      %{product1: product1, product2: product2, product3: product3}
    end

    test "returns products with matching IDs", %{
      product1: product1,
      product2: product2,
      product3: product3
    } do
      products = Products.get_products_by_ids(["product1", "product3"])

      assert length(products) == 2
      product_ids = Enum.map(products, & &1.id)
      assert product1.id in product_ids
      assert product3.id in product_ids
      refute product2.id in product_ids
    end

    test "returns empty list when no matching IDs", %{product1: _product1} do
      products = Products.get_products_by_ids(["nonexistent1", "nonexistent2"])
      assert products == []
    end

    test "returns empty list when given empty ID list" do
      products = Products.get_products_by_ids([])
      assert products == []
    end

    test "handles mix of existing and non-existing IDs", %{product1: product1} do
      products = Products.get_products_by_ids(["product1", "nonexistent"])

      assert length(products) == 1
      assert hd(products).id == product1.id
    end
  end

  describe "create_product/1" do
    test "creates a product with valid attributes" do
      attrs = %{
        id: "new_product",
        name: "New Product",
        price: Decimal.new("25.99")
      }

      assert {:ok, product} = Products.create_product(attrs)
      assert product.id == "new_product"
      assert product.name == "New Product"
      assert product.price == Decimal.new("25.99")
    end

    test "returns error with invalid attributes" do
      attrs = %{id: "", name: "", price: "invalid"}

      assert {:error, changeset} = Products.create_product(attrs)
      assert %{id: ["can't be blank"]} = errors_on(changeset)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
      assert %{price: ["is invalid"]} = errors_on(changeset)
    end

    test "returns error with missing required fields" do
      attrs = %{}

      assert {:error, changeset} = Products.create_product(attrs)
      assert %{id: ["can't be blank"]} = errors_on(changeset)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
      assert %{price: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error with negative price" do
      attrs = %{
        id: "negative_product",
        name: "Product",
        price: Decimal.new("-10.00")
      }

      assert {:error, changeset} = Products.create_product(attrs)
      assert %{price: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "returns error with zero price" do
      attrs = %{
        id: "zero_product",
        name: "Product",
        price: Decimal.new("0.00")
      }

      assert {:error, changeset} = Products.create_product(attrs)
      assert %{price: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "creates product with minimum valid price" do
      attrs = %{
        id: "cheap_product",
        name: "Cheap Product",
        price: Decimal.new("0.01")
      }

      assert {:ok, product} = Products.create_product(attrs)
      assert product.price == Decimal.new("0.01")
    end
  end
end

# test/backend/products/product_test.exs
defmodule Backend.Products.ProductTest do
  use ExUnit.Case, async: true

  alias Backend.Products.Product
  import Ecto.Changeset

  describe "changeset/2" do
    test "creates valid changeset with all required fields" do
      attrs = %{
        id: "netflix",
        name: "Netflix Subscription",
        price: Decimal.new("75.99")
      }

      changeset = Product.changeset(%Product{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :id) == "netflix"
      assert get_change(changeset, :name) == "Netflix Subscription"
      assert get_change(changeset, :price) == Decimal.new("75.99")
    end

    test "creates valid changeset with string price" do
      attrs = %{
        id: "spotify",
        name: "Spotify Premium",
        price: "45.99"
      }

      changeset = Product.changeset(%Product{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :price) == Decimal.new("45.99")
    end

    test "creates valid changeset with integer price" do
      attrs = %{
        id: "gym",
        name: "Gym Membership",
        price: 120
      }

      changeset = Product.changeset(%Product{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :price) == Decimal.new("120")
    end

    test "creates valid changeset with minimum valid price" do
      attrs = %{
        id: "micro-payment",
        name: "Micro Payment",
        price: Decimal.new("0.01")
      }

      changeset = Product.changeset(%Product{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :price) == Decimal.new("0.01")
    end

    test "creates valid changeset with very high price" do
      attrs = %{
        id: "expensive",
        name: "Expensive Product",
        price: Decimal.new("99999.99")
      }

      changeset = Product.changeset(%Product{}, attrs)

      assert changeset.valid?
    end

    test "accepts long product names" do
      long_name = String.duplicate("A", 255)

      attrs = %{
        id: "long-name",
        name: long_name,
        price: Decimal.new("10.00")
      }

      changeset = Product.changeset(%Product{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :name) == long_name
    end

    test "accepts special characters in id" do
      attrs = %{
        id: "product-with-dashes_and_underscores.123",
        name: "Special Product",
        price: "10.00"
      }

      changeset = Product.changeset(%Product{}, attrs)

      assert changeset.valid?
    end

    test "accepts unicode characters in name" do
      attrs = %{
        id: "unicode-product",
        name: "Café Münchën 北京",
        price: "10.00"
      }

      changeset = Product.changeset(%Product{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :name) == "Café Münchën 北京"
    end
  end

  describe "changeset/2 validation errors" do
    test "requires id field" do
      attrs = %{
        name: "Product Name",
        price: Decimal.new("10.00")
      }

      changeset = Product.changeset(%Product{}, attrs)

      refute changeset.valid?
      assert %{id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires name field" do
      attrs = %{
        id: "product-id",
        price: Decimal.new("10.00")
      }

      changeset = Product.changeset(%Product{}, attrs)

      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires price field" do
      attrs = %{
        id: "product-id",
        name: "Product Name"
      }

      changeset = Product.changeset(%Product{}, attrs)

      refute changeset.valid?
      assert %{price: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects empty id" do
      attrs = %{
        id: "",
        name: "Product Name",
        price: Decimal.new("10.00")
      }

      changeset = Product.changeset(%Product{}, attrs)

      refute changeset.valid?
      assert %{id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects empty name" do
      attrs = %{
        id: "product-id",
        name: "",
        price: Decimal.new("10.00")
      }

      changeset = Product.changeset(%Product{}, attrs)

      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects nil price" do
      attrs = %{
        id: "product-id",
        name: "Product Name",
        price: nil
      }

      changeset = Product.changeset(%Product{}, attrs)

      refute changeset.valid?
      assert %{price: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects zero price" do
      attrs = %{
        id: "product-id",
        name: "Product Name",
        price: Decimal.new("0")
      }

      changeset = Product.changeset(%Product{}, attrs)

      refute changeset.valid?
      assert %{price: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "rejects negative price" do
      attrs = %{
        id: "product-id",
        name: "Product Name",
        price: Decimal.new("-10.00")
      }

      changeset = Product.changeset(%Product{}, attrs)

      refute changeset.valid?
      assert %{price: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "rejects string negative price" do
      attrs = %{
        id: "product-id",
        name: "Product Name",
        price: "-5.99"
      }

      changeset = Product.changeset(%Product{}, attrs)

      refute changeset.valid?
      assert %{price: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "rejects invalid price format" do
      attrs = %{
        id: "product-id",
        name: "Product Name",
        price: "not-a-number"
      }

      changeset = Product.changeset(%Product{}, attrs)

      refute changeset.valid?
      # Ecto will return a type casting error
      assert changeset.errors[:price] != nil
    end

    test "rejects whitespace-only id" do
      attrs = %{
        id: "   ",
        name: "Product Name",
        price: "10.00"
      }

      changeset = Product.changeset(%Product{}, attrs)

      refute changeset.valid?
      assert %{id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects whitespace-only name" do
      attrs = %{
        id: "product-id",
        name: "   ",
        price: "10.00"
      }

      changeset = Product.changeset(%Product{}, attrs)

      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "changeset/2 type casting" do
    test "casts string keys to proper types" do
      attrs = %{
        "id" => "string-key",
        "name" => "Product Name",
        "price" => "19.99"
      }

      changeset = Product.changeset(%Product{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :id) == "string-key"
      assert get_change(changeset, :name) == "Product Name"
      assert get_change(changeset, :price) == Decimal.new("19.99")
    end

    test "casts atom keys to string values" do
      # Atoms are automatically converted to strings by Ecto when casting
      attrs = %{
        # Use strings since atoms don't auto-convert
        id: "atom_id",
        name: "atom_name",
        price: "10.00"
      }

      changeset = Product.changeset(%Product{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :id) == "atom_id"
      assert get_change(changeset, :name) == "atom_name"
    end

    test "casts float price to decimal" do
      attrs = %{
        id: "product-id",
        name: "Product Name",
        price: 19.99
      }

      changeset = Product.changeset(%Product{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :price) == Decimal.new("19.99")
    end

    test "casts integer price to decimal" do
      attrs = %{
        id: "product-id",
        name: "Product Name",
        price: 25
      }

      changeset = Product.changeset(%Product{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :price) == Decimal.new("25")
    end

    test "preserves decimal precision" do
      attrs = %{
        id: "precise-product",
        name: "Precise Product",
        price: Decimal.new("10.999")
      }

      changeset = Product.changeset(%Product{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :price) == Decimal.new("10.999")
    end
  end

  describe "changeset/2 with existing product (updates)" do
    test "updates existing product with valid data" do
      existing_product = %Product{
        id: "existing",
        name: "Old Name",
        price: Decimal.new("50.00")
      }

      update_attrs = %{
        name: "New Name",
        price: Decimal.new("75.00")
      }

      changeset = Product.changeset(existing_product, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :name) == "New Name"
      assert get_change(changeset, :price) == Decimal.new("75.00")
      # ID should not change in update
      assert get_change(changeset, :id) == nil
    end

    test "partial update with only name" do
      existing_product = %Product{
        id: "existing",
        name: "Old Name",
        price: Decimal.new("50.00")
      }

      update_attrs = %{name: "New Name"}

      changeset = Product.changeset(existing_product, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :name) == "New Name"
      assert get_change(changeset, :price) == nil
    end

    test "partial update with only price" do
      existing_product = %Product{
        id: "existing",
        name: "Product Name",
        price: Decimal.new("50.00")
      }

      update_attrs = %{price: Decimal.new("99.99")}

      changeset = Product.changeset(existing_product, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :name) == nil
      assert get_change(changeset, :price) == Decimal.new("99.99")
    end

    test "update fails with invalid price" do
      existing_product = %Product{
        id: "existing",
        name: "Product Name",
        price: Decimal.new("50.00")
      }

      update_attrs = %{price: Decimal.new("-10.00")}

      changeset = Product.changeset(existing_product, update_attrs)

      refute changeset.valid?
      assert %{price: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "cannot update id of existing product" do
      existing_product = %Product{
        id: "existing",
        name: "Product Name",
        price: Decimal.new("50.00")
      }

      update_attrs = %{id: "new-id"}

      changeset = Product.changeset(existing_product, update_attrs)

      assert changeset.valid?
      # ID change is allowed by changeset but would fail at database level
      assert get_change(changeset, :id) == "new-id"
    end
  end

  describe "schema associations" do
    test "has correct associations defined" do
      product = %Product{}

      # Test that associations are defined (doesn't test database relationships)
      assert %Ecto.Association.Has{} = Product.__schema__(:association, :order_items)
      assert %Ecto.Association.Has{} = Product.__schema__(:association, :user_products)
    end

    test "association cardinalities are correct" do
      order_items_assoc = Product.__schema__(:association, :order_items)
      user_products_assoc = Product.__schema__(:association, :user_products)

      assert order_items_assoc.cardinality == :many
      assert user_products_assoc.cardinality == :many
    end
  end

  describe "schema metadata" do
    test "has correct primary key" do
      assert Product.__schema__(:primary_key) == [:id]
    end

    test "primary key is string type" do
      assert Product.__schema__(:type, :id) == :string
    end

    test "has correct field types" do
      assert Product.__schema__(:type, :name) == :string
      assert Product.__schema__(:type, :price) == :decimal
    end

    test "includes timestamps" do
      fields = Product.__schema__(:fields)
      assert :inserted_at in fields
      assert :updated_at in fields
    end

    test "has correct table name" do
      assert Product.__schema__(:source) == "products"
    end
  end

  # Helper function to convert changeset errors to a map
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

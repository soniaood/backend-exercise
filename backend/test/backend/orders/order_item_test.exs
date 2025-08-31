defmodule Backend.Orders.OrderItemTest do
  use ExUnit.Case, async: true

  alias Backend.Orders.OrderItem
  import Ecto.Changeset

  describe "changeset/2" do
    test "creates valid changeset with all required fields" do
      attrs = %{
        price: Decimal.new("29.99"),
        order_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "550e8400-e29b-41d4-a716-446612345000"
      }

      changeset = OrderItem.changeset(%OrderItem{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :price) == Decimal.new("29.99")
      assert get_change(changeset, :order_id) == "550e8400-e29b-41d4-a716-446655440000"
      assert get_change(changeset, :product_id) == "550e8400-e29b-41d4-a716-446612345000"
    end

    test "accepts string price" do
      attrs = %{
        price: "150.75",
        order_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "spotify"
      }

      changeset = OrderItem.changeset(%OrderItem{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :price) == Decimal.new("150.75")
    end

    test "accepts integer price" do
      attrs = %{
        price: 100,
        order_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "gym"
      }

      changeset = OrderItem.changeset(%OrderItem{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :price) == Decimal.new("100")
    end

    test "accepts float price" do
      attrs = %{
        price: 25.99,
        order_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "product-123"
      }

      changeset = OrderItem.changeset(%OrderItem{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :price) == Decimal.new("25.99")
    end

    test "accepts minimum valid price" do
      attrs = %{
        price: Decimal.new("0.01"),
        order_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "micro-payment"
      }

      changeset = OrderItem.changeset(%OrderItem{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :price) == Decimal.new("0.01")
    end

    test "preserves decimal precision" do
      attrs = %{
        price: Decimal.new("10.999"),
        order_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "precise-product"
      }

      changeset = OrderItem.changeset(%OrderItem{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :price) == Decimal.new("10.999")
    end
  end

  describe "changeset/2 validation errors" do
    test "requires price field" do
      attrs = %{
        order_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "product-123"
      }

      changeset = OrderItem.changeset(%OrderItem{}, attrs)

      refute changeset.valid?
      assert %{price: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires order_id field" do
      attrs = %{
        price: Decimal.new("99.99"),
        product_id: "product-123"
      }

      changeset = OrderItem.changeset(%OrderItem{}, attrs)

      refute changeset.valid?
      assert %{order_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires product_id field" do
      attrs = %{
        price: Decimal.new("99.99"),
        order_id: "550e8400-e29b-41d4-a716-446655440000"
      }

      changeset = OrderItem.changeset(%OrderItem{}, attrs)

      refute changeset.valid?
      assert %{product_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects nil price" do
      attrs = %{
        price: nil,
        order_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "product-123"
      }

      changeset = OrderItem.changeset(%OrderItem{}, attrs)

      refute changeset.valid?
      assert %{price: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects nil order_id" do
      attrs = %{
        price: Decimal.new("99.99"),
        order_id: nil,
        product_id: "product-123"
      }

      changeset = OrderItem.changeset(%OrderItem{}, attrs)

      refute changeset.valid?
      assert %{order_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects nil product_id" do
      attrs = %{
        price: Decimal.new("99.99"),
        order_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: nil
      }

      changeset = OrderItem.changeset(%OrderItem{}, attrs)

      refute changeset.valid?
      assert %{product_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects zero price" do
      attrs = %{
        price: Decimal.new("0"),
        order_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "product-123"
      }

      changeset = OrderItem.changeset(%OrderItem{}, attrs)

      refute changeset.valid?
      assert %{price: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "rejects negative price" do
      attrs = %{
        price: Decimal.new("-10.00"),
        order_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "product-123"
      }

      changeset = OrderItem.changeset(%OrderItem{}, attrs)

      refute changeset.valid?
      assert %{price: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "rejects invalid price format" do
      attrs = %{
        price: "not-a-number",
        order_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "product-123"
      }

      changeset = OrderItem.changeset(%OrderItem{}, attrs)

      refute changeset.valid?
      # Ecto will return a type casting error
      assert changeset.errors[:price] != nil
    end

    test "rejects empty order_id" do
      attrs = %{
        price: Decimal.new("99.99"),
        order_id: "",
        product_id: "product-123"
      }

      changeset = OrderItem.changeset(%OrderItem{}, attrs)

      refute changeset.valid?
      assert %{order_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects empty product_id" do
      attrs = %{
        price: Decimal.new("99.99"),
        order_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: ""
      }

      changeset = OrderItem.changeset(%OrderItem{}, attrs)

      refute changeset.valid?
      assert %{product_id: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "changeset/2 type casting" do
    test "casts string keys to proper types" do
      attrs = %{
        "price" => "125.50",
        "order_id" => "550e8400-e29b-41d4-a716-446655440000",
        "product_id" => "product-abc"
      }

      changeset = OrderItem.changeset(%OrderItem{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :price) == Decimal.new("125.50")
      assert get_change(changeset, :order_id) == "550e8400-e29b-41d4-a716-446655440000"
      assert get_change(changeset, :product_id) == "product-abc"
    end

    test "casts float price to decimal" do
      attrs = %{
        price: 19.99,
        order_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "product-123"
      }

      changeset = OrderItem.changeset(%OrderItem{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :price) == Decimal.new("19.99")
    end

    test "casts integer price to decimal" do
      attrs = %{
        price: 25,
        order_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "product-123"
      }

      changeset = OrderItem.changeset(%OrderItem{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :price) == Decimal.new("25")
    end
  end

  describe "changeset/2 with existing order item (updates)" do
    test "updates existing order item with valid data" do
      existing_order_item = %OrderItem{
        id: "550e8400-e29b-41d4-a716-446655440000",
        price: Decimal.new("50.00"),
        order_id: "550e8400-e29b-41d4-a716-446655440001",
        product_id: "old-product"
      }

      update_attrs = %{
        price: Decimal.new("75.00")
      }

      changeset = OrderItem.changeset(existing_order_item, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :price) == Decimal.new("75.00")
      # Not being updated
      assert get_change(changeset, :order_id) == nil
      # Not being updated
      assert get_change(changeset, :product_id) == nil
    end

    test "update fails with invalid price" do
      existing_order_item = %OrderItem{
        id: "550e8400-e29b-41d4-a716-446655440000",
        price: Decimal.new("50.00"),
        order_id: "550e8400-e29b-41d4-a716-446655440001",
        product_id: "product-123"
      }

      update_attrs = %{price: Decimal.new("-10.00")}

      changeset = OrderItem.changeset(existing_order_item, update_attrs)

      refute changeset.valid?
      assert %{price: ["must be greater than 0"]} = errors_on(changeset)
    end
  end

  describe "schema associations" do
    test "has correct associations defined" do
      order_item = %OrderItem{}

      assert %Ecto.Association.BelongsTo{} = OrderItem.__schema__(:association, :order)
      assert %Ecto.Association.BelongsTo{} = OrderItem.__schema__(:association, :product)
    end

    test "association cardinalities are correct" do
      order_assoc = OrderItem.__schema__(:association, :order)
      product_assoc = OrderItem.__schema__(:association, :product)

      assert order_assoc.cardinality == :one
      assert product_assoc.cardinality == :one
    end

    test "belongs_to associations have correct relationships" do
      order_assoc = OrderItem.__schema__(:association, :order)
      product_assoc = OrderItem.__schema__(:association, :product)

      assert order_assoc.owner_key == :order_id
      assert order_assoc.related_key == :id
      assert order_assoc.related == Backend.Orders.Order

      assert product_assoc.owner_key == :product_id
      assert product_assoc.related_key == :id
      assert product_assoc.related == Backend.Products.Product
    end

    test "product association uses binary_id type" do
      product_assoc = OrderItem.__schema__(:association, :product)
      # Check that the product_id field type matches the product's binary_id type
      assert OrderItem.__schema__(:type, :product_id) == :binary_id
    end
  end

  describe "schema metadata" do
    test "has correct primary key" do
      assert OrderItem.__schema__(:primary_key) == [:id]
    end

    test "primary key is binary_id type" do
      assert OrderItem.__schema__(:type, :id) == :binary_id
    end

    test "has correct field types" do
      assert OrderItem.__schema__(:type, :price) == :decimal
      assert OrderItem.__schema__(:type, :order_id) == :binary_id
      assert OrderItem.__schema__(:type, :product_id) == :binary_id
    end

    test "includes timestamps" do
      fields = OrderItem.__schema__(:fields)
      assert :inserted_at in fields
      assert :updated_at in fields
    end

    test "has correct table name" do
      assert OrderItem.__schema__(:source) == "order_items"
    end

    test "foreign key type configuration" do
      # All foreign keys use binary_id
      order_assoc = OrderItem.__schema__(:association, :order)
      assert order_assoc.owner_key == :order_id

      assert OrderItem.__schema__(:type, :product_id) == :binary_id
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

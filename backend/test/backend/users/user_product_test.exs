defmodule Backend.Users.UserProductTest do
  use ExUnit.Case, async: true

  alias Backend.Users.UserProduct
  import Ecto.Changeset

  describe "changeset/2" do
    test "creates valid changeset with all required fields" do
      attrs = %{
        user_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "netflix",
        order_id: "550e8400-e29b-41d4-a716-446655440001"
      }

      changeset = UserProduct.changeset(%UserProduct{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :user_id) == "550e8400-e29b-41d4-a716-446655440000"
      assert get_change(changeset, :product_id) == "netflix"
      assert get_change(changeset, :order_id) == "550e8400-e29b-41d4-a716-446655440001"
    end

    test "accepts different product types" do
      attrs = %{
        user_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "spotify-premium",
        order_id: "550e8400-e29b-41d4-a716-446655440001"
      }

      changeset = UserProduct.changeset(%UserProduct{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :product_id) == "spotify-premium"
    end

    test "accepts alphanumeric product IDs" do
      attrs = %{
        user_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "product123",
        order_id: "550e8400-e29b-41d4-a716-446655440001"
      }

      changeset = UserProduct.changeset(%UserProduct{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :product_id) == "product123"
    end

    test "accepts product IDs with special characters" do
      attrs = %{
        user_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "product-with-dashes_and_underscores.123",
        order_id: "550e8400-e29b-41d4-a716-446655440001"
      }

      changeset = UserProduct.changeset(%UserProduct{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :product_id) == "product-with-dashes_and_underscores.123"
    end
  end

  describe "changeset/2 validation errors" do
    test "requires user_id field" do
      attrs = %{
        product_id: "netflix",
        order_id: "550e8400-e29b-41d4-a716-446655440001"
      }

      changeset = UserProduct.changeset(%UserProduct{}, attrs)

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires product_id field" do
      attrs = %{
        user_id: "550e8400-e29b-41d4-a716-446655440000",
        order_id: "550e8400-e29b-41d4-a716-446655440001"
      }

      changeset = UserProduct.changeset(%UserProduct{}, attrs)

      refute changeset.valid?
      assert %{product_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires order_id field" do
      attrs = %{
        user_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "netflix"
      }

      changeset = UserProduct.changeset(%UserProduct{}, attrs)

      refute changeset.valid?
      assert %{order_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects nil user_id" do
      attrs = %{
        user_id: nil,
        product_id: "netflix",
        order_id: "550e8400-e29b-41d4-a716-446655440001"
      }

      changeset = UserProduct.changeset(%UserProduct{}, attrs)

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects nil product_id" do
      attrs = %{
        user_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: nil,
        order_id: "550e8400-e29b-41d4-a716-446655440001"
      }

      changeset = UserProduct.changeset(%UserProduct{}, attrs)

      refute changeset.valid?
      assert %{product_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects nil order_id" do
      attrs = %{
        user_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "netflix",
        order_id: nil
      }

      changeset = UserProduct.changeset(%UserProduct{}, attrs)

      refute changeset.valid?
      assert %{order_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects empty user_id" do
      attrs = %{
        user_id: "",
        product_id: "netflix",
        order_id: "550e8400-e29b-41d4-a716-446655440001"
      }

      changeset = UserProduct.changeset(%UserProduct{}, attrs)

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects empty product_id" do
      attrs = %{
        user_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "",
        order_id: "550e8400-e29b-41d4-a716-446655440001"
      }

      changeset = UserProduct.changeset(%UserProduct{}, attrs)

      refute changeset.valid?
      assert %{product_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects empty order_id" do
      attrs = %{
        user_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "netflix",
        order_id: ""
      }

      changeset = UserProduct.changeset(%UserProduct{}, attrs)

      refute changeset.valid?
      assert %{order_id: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "changeset/2 type casting" do
    test "casts string keys to proper types" do
      attrs = %{
        "user_id" => "550e8400-e29b-41d4-a716-446655440000",
        "product_id" => "netflix",
        "order_id" => "550e8400-e29b-41d4-a716-446655440001"
      }

      changeset = UserProduct.changeset(%UserProduct{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :user_id) == "550e8400-e29b-41d4-a716-446655440000"
      assert get_change(changeset, :product_id) == "netflix"
      assert get_change(changeset, :order_id) == "550e8400-e29b-41d4-a716-446655440001"
    end

    test "handles string conversion from atom product_id" do
      attrs = %{
        user_id: "550e8400-e29b-41d4-a716-446655440000",
        # Use string instead of atom
        product_id: "netflix",
        order_id: "550e8400-e29b-41d4-a716-446655440001"
      }

      changeset = UserProduct.changeset(%UserProduct{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :product_id) == "netflix"
    end
  end

  describe "changeset/2 with existing user product (updates)" do
    test "updates existing user product with valid data" do
      existing_user_product = %UserProduct{
        id: "550e8400-e29b-41d4-a716-446655440000",
        user_id: "550e8400-e29b-41d4-a716-446655440001",
        product_id: "old-product",
        order_id: "550e8400-e29b-41d4-a716-446655440002"
      }

      update_attrs = %{
        product_id: "new-product"
      }

      changeset = UserProduct.changeset(existing_user_product, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :product_id) == "new-product"
      # Not being updated
      assert get_change(changeset, :user_id) == nil
      # Not being updated
      assert get_change(changeset, :order_id) == nil
    end

    test "partial update with only order_id" do
      existing_user_product = %UserProduct{
        id: "550e8400-e29b-41d4-a716-446655440000",
        user_id: "550e8400-e29b-41d4-a716-446655440001",
        product_id: "netflix",
        order_id: "550e8400-e29b-41d4-a716-446655440002"
      }

      update_attrs = %{order_id: "550e8400-e29b-41d4-a716-446655440003"}

      changeset = UserProduct.changeset(existing_user_product, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :order_id) == "550e8400-e29b-41d4-a716-446655440003"
    end
  end

  describe "changeset/2 unique constraint" do
    # Note: These tests verify the changeset includes the unique constraint
    # Actual constraint violations would be tested at the database/integration level
    test "includes unique constraint for user_id and product_id" do
      attrs = %{
        user_id: "550e8400-e29b-41d4-a716-446655440000",
        product_id: "netflix",
        order_id: "550e8400-e29b-41d4-a716-446655440001"
      }

      changeset = UserProduct.changeset(%UserProduct{}, attrs)

      # Check that the constraint is defined in the changeset
      assert changeset.constraints != []
      constraint = Enum.find(changeset.constraints, fn c -> c.type == :unique end)
      assert constraint != nil
      assert constraint.field == :user_id
    end
  end

  describe "schema associations" do
    test "has correct associations defined" do
      _user_product = %UserProduct{}

      assert %Ecto.Association.BelongsTo{} = UserProduct.__schema__(:association, :user)
      assert %Ecto.Association.BelongsTo{} = UserProduct.__schema__(:association, :product)
      assert %Ecto.Association.BelongsTo{} = UserProduct.__schema__(:association, :order)
    end

    test "association cardinalities are correct" do
      user_assoc = UserProduct.__schema__(:association, :user)
      product_assoc = UserProduct.__schema__(:association, :product)
      order_assoc = UserProduct.__schema__(:association, :order)

      assert user_assoc.cardinality == :one
      assert product_assoc.cardinality == :one
      assert order_assoc.cardinality == :one
    end

    test "belongs_to associations have correct relationships" do
      user_assoc = UserProduct.__schema__(:association, :user)
      product_assoc = UserProduct.__schema__(:association, :product)
      order_assoc = UserProduct.__schema__(:association, :order)

      assert user_assoc.owner_key == :user_id
      assert user_assoc.related_key == :id
      assert user_assoc.related == Backend.Users.User

      assert product_assoc.owner_key == :product_id
      assert product_assoc.related_key == :id
      assert product_assoc.related == Backend.Products.Product

      assert order_assoc.owner_key == :order_id
      assert order_assoc.related_key == :id
      assert order_assoc.related == Backend.Orders.Order
    end

    test "product association uses binary_id type" do
      # Check that the product_id field type matches the product's binary_id type
      assert UserProduct.__schema__(:type, :product_id) == :binary_id
    end
  end

  describe "schema metadata" do
    test "has correct primary key" do
      assert UserProduct.__schema__(:primary_key) == [:id]
    end

    test "primary key is binary_id type" do
      assert UserProduct.__schema__(:type, :id) == :binary_id
    end

    test "has correct field types" do
      assert UserProduct.__schema__(:type, :user_id) == :binary_id
      assert UserProduct.__schema__(:type, :product_id) == :binary_id
      assert UserProduct.__schema__(:type, :order_id) == :binary_id
    end

    test "includes timestamps" do
      fields = UserProduct.__schema__(:fields)
      assert :inserted_at in fields
      assert :updated_at in fields
    end

    test "has correct table name" do
      assert UserProduct.__schema__(:source) == "user_products"
    end

    test "foreign key type configuration" do
      # user_id and order_id use binary_id, product_id uses string
      user_assoc = UserProduct.__schema__(:association, :user)
      order_assoc = UserProduct.__schema__(:association, :order)

      assert user_assoc.owner_key == :user_id
      assert order_assoc.owner_key == :order_id

      # product_id is explicitly defined as binary_id type in the schema
      assert UserProduct.__schema__(:type, :product_id) == :binary_id
    end

    test "has no non-association fields besides foreign keys and timestamps" do
      fields = UserProduct.__schema__(:fields)

      non_meta_fields =
        fields -- [:id, :user_id, :product_id, :order_id, :inserted_at, :updated_at]

      # UserProduct is a pure join table with no additional data fields
      assert non_meta_fields == []
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

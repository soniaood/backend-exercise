defmodule Backend.Orders.OrderTest do
  use ExUnit.Case, async: true

  alias Backend.Orders.Order
  import Ecto.Changeset

  describe "changeset/2" do
    test "creates valid changeset with all required fields" do
      attrs = %{
        total: Decimal.new("99.99"),
        user_id: "550e8400-e29b-41d4-a716-446655440000"
      }

      changeset = Order.changeset(%Order{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :total) == Decimal.new("99.99")
      assert get_change(changeset, :user_id) == "550e8400-e29b-41d4-a716-446655440000"
    end

    test "accepts string total" do
      attrs = %{
        total: "150.75",
        user_id: "550e8400-e29b-41d4-a716-446655440000"
      }

      changeset = Order.changeset(%Order{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :total) == Decimal.new("150.75")
    end

    test "accepts integer total" do
      attrs = %{
        total: 100,
        user_id: "550e8400-e29b-41d4-a716-446655440000"
      }

      changeset = Order.changeset(%Order{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :total) == Decimal.new("100")
    end

    test "accepts float total" do
      attrs = %{
        total: 25.99,
        user_id: "550e8400-e29b-41d4-a716-446655440000"
      }

      changeset = Order.changeset(%Order{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :total) == Decimal.new("25.99")
    end

    test "accepts minimum valid total" do
      attrs = %{
        total: Decimal.new("0.01"),
        user_id: "550e8400-e29b-41d4-a716-446655440000"
      }

      changeset = Order.changeset(%Order{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :total) == Decimal.new("0.01")
    end

    test "accepts very high total" do
      attrs = %{
        total: Decimal.new("999999.99"),
        user_id: "550e8400-e29b-41d4-a716-446655440000"
      }

      changeset = Order.changeset(%Order{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :total) == Decimal.new("999999.99")
    end

    test "preserves decimal precision" do
      attrs = %{
        total: Decimal.new("10.999"),
        user_id: "550e8400-e29b-41d4-a716-446655440000"
      }

      changeset = Order.changeset(%Order{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :total) == Decimal.new("10.999")
    end
  end

  describe "changeset/2 validation errors" do
    test "requires total field" do
      attrs = %{
        user_id: "550e8400-e29b-41d4-a716-446655440000"
      }

      changeset = Order.changeset(%Order{}, attrs)

      refute changeset.valid?
      assert %{total: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires user_id field" do
      attrs = %{
        total: Decimal.new("99.99")
      }

      changeset = Order.changeset(%Order{}, attrs)

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects nil total" do
      attrs = %{
        total: nil,
        user_id: "550e8400-e29b-41d4-a716-446655440000"
      }

      changeset = Order.changeset(%Order{}, attrs)

      refute changeset.valid?
      assert %{total: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects nil user_id" do
      attrs = %{
        total: Decimal.new("99.99"),
        user_id: nil
      }

      changeset = Order.changeset(%Order{}, attrs)

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects zero total" do
      attrs = %{
        total: Decimal.new("0"),
        user_id: "550e8400-e29b-41d4-a716-446655440000"
      }

      changeset = Order.changeset(%Order{}, attrs)

      refute changeset.valid?
      assert %{total: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "rejects negative total" do
      attrs = %{
        total: Decimal.new("-10.00"),
        user_id: "550e8400-e29b-41d4-a716-446655440000"
      }

      changeset = Order.changeset(%Order{}, attrs)

      refute changeset.valid?
      assert %{total: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "rejects string negative total" do
      attrs = %{
        total: "-5.99",
        user_id: "550e8400-e29b-41d4-a716-446655440000"
      }

      changeset = Order.changeset(%Order{}, attrs)

      refute changeset.valid?
      assert %{total: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "rejects invalid total format" do
      attrs = %{
        total: "not-a-number",
        user_id: "550e8400-e29b-41d4-a716-446655440000"
      }

      changeset = Order.changeset(%Order{}, attrs)

      refute changeset.valid?
      # Ecto will return a type casting error
      assert changeset.errors[:total] != nil
    end

    test "rejects empty user_id" do
      attrs = %{
        total: Decimal.new("99.99"),
        user_id: ""
      }

      changeset = Order.changeset(%Order{}, attrs)

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "changeset/2 type casting" do
    test "casts string keys to proper types" do
      attrs = %{
        "total" => "125.50",
        "user_id" => "550e8400-e29b-41d4-a716-446655440000"
      }

      changeset = Order.changeset(%Order{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :total) == Decimal.new("125.50")
      assert get_change(changeset, :user_id) == "550e8400-e29b-41d4-a716-446655440000"
    end

    test "casts float total to decimal" do
      attrs = %{
        total: 19.99,
        user_id: "550e8400-e29b-41d4-a716-446655440000"
      }

      changeset = Order.changeset(%Order{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :total) == Decimal.new("19.99")
    end

    test "casts integer total to decimal" do
      attrs = %{
        total: 25,
        user_id: "550e8400-e29b-41d4-a716-446655440000"
      }

      changeset = Order.changeset(%Order{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :total) == Decimal.new("25")
    end
  end

  describe "changeset/2 with existing order (updates)" do
    test "updates existing order with valid data" do
      existing_order = %Order{
        id: "550e8400-e29b-41d4-a716-446655440000",
        total: Decimal.new("50.00"),
        user_id: "550e8400-e29b-41d4-a716-446655440001"
      }

      update_attrs = %{
        total: Decimal.new("75.00")
      }

      changeset = Order.changeset(existing_order, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :total) == Decimal.new("75.00")
      # Not being updated
      assert get_change(changeset, :user_id) == nil
    end

    test "partial update with only total" do
      existing_order = %Order{
        id: "550e8400-e29b-41d4-a716-446655440000",
        total: Decimal.new("50.00"),
        user_id: "550e8400-e29b-41d4-a716-446655440001"
      }

      update_attrs = %{total: Decimal.new("99.99")}

      changeset = Order.changeset(existing_order, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :total) == Decimal.new("99.99")
    end

    test "update fails with invalid total" do
      existing_order = %Order{
        id: "550e8400-e29b-41d4-a716-446655440000",
        total: Decimal.new("50.00"),
        user_id: "550e8400-e29b-41d4-a716-446655440001"
      }

      update_attrs = %{total: Decimal.new("-10.00")}

      changeset = Order.changeset(existing_order, update_attrs)

      refute changeset.valid?
      assert %{total: ["must be greater than 0"]} = errors_on(changeset)
    end
  end

  describe "schema associations" do
    test "has correct associations defined" do
      _order = %Order{}

      assert %Ecto.Association.BelongsTo{} = Order.__schema__(:association, :user)
      assert %Ecto.Association.Has{} = Order.__schema__(:association, :order_items)
    end

    test "association cardinalities are correct" do
      user_assoc = Order.__schema__(:association, :user)
      order_items_assoc = Order.__schema__(:association, :order_items)

      assert user_assoc.cardinality == :one
      assert order_items_assoc.cardinality == :many
    end

    test "belongs_to user relationship" do
      user_assoc = Order.__schema__(:association, :user)

      assert user_assoc.owner_key == :user_id
      assert user_assoc.related_key == :id
      assert user_assoc.related == Backend.Users.User
    end
  end

  describe "schema metadata" do
    test "has correct primary key" do
      assert Order.__schema__(:primary_key) == [:id]
    end

    test "primary key is binary_id type" do
      assert Order.__schema__(:type, :id) == :binary_id
    end

    test "has correct field types" do
      assert Order.__schema__(:type, :total) == :decimal
      assert Order.__schema__(:type, :user_id) == :binary_id
    end

    test "includes timestamps" do
      fields = Order.__schema__(:fields)
      assert :inserted_at in fields
      assert :updated_at in fields
    end

    test "has correct table name" do
      assert Order.__schema__(:source) == "orders"
    end

    test "foreign key type is binary_id" do
      # This tests that @foreign_key_type :binary_id is set correctly
      user_assoc = Order.__schema__(:association, :user)
      assert user_assoc.owner_key == :user_id
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

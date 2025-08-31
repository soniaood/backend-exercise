defmodule Backend.Users.UserTest do
  use ExUnit.Case, async: true

  alias Backend.Users.User
  import Ecto.Changeset

  describe "registration_changeset/2" do
    test "creates valid changeset with all required fields" do
      attrs = %{
        username: "testuser",
        email: "test@example.com",
        password: "Password123!"
      }

      changeset = User.registration_changeset(%User{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :username) == "testuser"
      assert get_change(changeset, :email) == "test@example.com"
      assert get_change(changeset, :password_hash) != nil
      # Balance is set via default and put_change with same value, so it doesn't appear in changes
      assert get_field(changeset, :balance) == Decimal.new("1000.00")
      # Should be removed
      refute get_change(changeset, :password)
    end

    test "hashes password correctly" do
      attrs = %{
        username: "testuser",
        email: "test@example.com",
        password: "Password123!"
      }

      changeset = User.registration_changeset(%User{}, attrs)
      password_hash = get_change(changeset, :password_hash)

      assert password_hash != nil
      assert String.starts_with?(password_hash, "$2b$")
      assert Bcrypt.verify_pass("Password123!", password_hash)
    end

    test "sets default balance to 1000.00" do
      attrs = %{
        username: "testuser",
        email: "test@example.com",
        password: "Password123!"
      }

      changeset = User.registration_changeset(%User{}, attrs)

      assert changeset.valid?
      # Balance is set via default and put_change with same value, so it doesn't appear in changes
      assert get_field(changeset, :balance) == Decimal.new("1000.00")
    end
  end

  describe "registration_changeset/2 validation errors" do
    test "requires username field" do
      attrs = %{
        email: "test@example.com",
        password: "Password123!"
      }

      changeset = User.registration_changeset(%User{}, attrs)

      refute changeset.valid?
      assert %{username: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires email field" do
      attrs = %{
        username: "testuser",
        password: "Password123!"
      }

      changeset = User.registration_changeset(%User{}, attrs)

      refute changeset.valid?
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires password field" do
      attrs = %{
        username: "testuser",
        email: "test@example.com"
      }

      changeset = User.registration_changeset(%User{}, attrs)

      refute changeset.valid?
      assert %{password: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects empty username" do
      attrs = %{
        username: "",
        email: "test@example.com",
        password: "Password123!"
      }

      changeset = User.registration_changeset(%User{}, attrs)

      refute changeset.valid?
      assert %{username: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects empty email" do
      attrs = %{
        username: "testuser",
        email: "",
        password: "Password123!"
      }

      changeset = User.registration_changeset(%User{}, attrs)

      refute changeset.valid?
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email format" do
      attrs = %{
        username: "testuser",
        email: "invalid-email",
        password: "Password123!"
      }

      changeset = User.registration_changeset(%User{}, attrs)

      refute changeset.valid?
      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "rejects email with spaces" do
      attrs = %{
        username: "testuser",
        email: "test @example.com",
        password: "Password123!"
      }

      changeset = User.registration_changeset(%User{}, attrs)

      refute changeset.valid?
      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates email length" do
      long_email = String.duplicate("a", 150) <> "@example.com"

      attrs = %{
        username: "testuser",
        email: long_email,
        password: "Password123!"
      }

      changeset = User.registration_changeset(%User{}, attrs)

      refute changeset.valid?
      assert %{email: ["should be at most 160 character(s)"]} = errors_on(changeset)
    end

    test "validates password length minimum" do
      attrs = %{
        username: "testuser",
        email: "test@example.com",
        password: "123"
      }

      changeset = User.registration_changeset(%User{}, attrs)

      refute changeset.valid?
      errors = errors_on(changeset)
      assert "should be at least 6 character(s)" in errors.password
    end

    test "validates password length maximum" do
      long_password = String.duplicate("A", 73) <> "1!"

      attrs = %{
        username: "testuser",
        email: "test@example.com",
        password: long_password
      }

      changeset = User.registration_changeset(%User{}, attrs)

      refute changeset.valid?
      errors = errors_on(changeset)
      assert "should be at most 72 character(s)" in errors.password
    end

    test "validates password has lowercase character" do
      attrs = %{
        username: "testuser",
        email: "test@example.com",
        password: "PASSWORD123!"
      }

      changeset = User.registration_changeset(%User{}, attrs)

      refute changeset.valid?
      errors = errors_on(changeset)
      assert "at least one lower case character" in errors.password
    end

    test "validates password has uppercase character" do
      attrs = %{
        username: "testuser",
        email: "test@example.com",
        password: "password123!"
      }

      changeset = User.registration_changeset(%User{}, attrs)

      refute changeset.valid?
      errors = errors_on(changeset)
      assert "at least one upper case character" in errors.password
    end

    test "validates password has digit or punctuation" do
      attrs = %{
        username: "testuser",
        email: "test@example.com",
        password: "Password"
      }

      changeset = User.registration_changeset(%User{}, attrs)

      refute changeset.valid?
      errors = errors_on(changeset)
      assert "at least one digit or punctuation character" in errors.password
    end
  end

  describe "changeset/2 for updates" do
    test "updates user with valid data" do
      existing_user = %User{
        username: "olduser",
        email: "old@example.com",
        balance: Decimal.new("500.00")
      }

      attrs = %{
        username: "newuser",
        balance: Decimal.new("750.00")
      }

      changeset = User.changeset(existing_user, attrs)

      assert changeset.valid?
      assert get_change(changeset, :username) == "newuser"
      assert get_change(changeset, :balance) == Decimal.new("750.00")
    end

    test "validates balance is not negative" do
      existing_user = %User{
        username: "testuser",
        balance: Decimal.new("100.00")
      }

      attrs = %{balance: Decimal.new("-10.00")}

      changeset = User.changeset(existing_user, attrs)

      refute changeset.valid?
      assert %{balance: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end

    test "allows zero balance" do
      existing_user = %User{
        username: "testuser",
        balance: Decimal.new("100.00")
      }

      attrs = %{balance: Decimal.new("0.00")}

      changeset = User.changeset(existing_user, attrs)

      assert changeset.valid?
      assert get_change(changeset, :balance) == Decimal.new("0.00")
    end
  end

  describe "create_changeset/2 for legacy support" do
    test "creates user with default balance" do
      attrs = %{username: "newuser"}

      changeset = User.create_changeset(%User{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :username) == "newuser"
      # Balance is set via default and put_change with same value, so it doesn't appear in changes
      assert get_field(changeset, :balance) == Decimal.new("1000.00")
    end

    test "requires username" do
      attrs = %{}

      changeset = User.create_changeset(%User{}, attrs)

      refute changeset.valid?
      assert %{username: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "login_changeset/2" do
    test "validates password field" do
      attrs = %{password: "testpassword"}

      changeset = User.login_changeset(%User{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :password) == "testpassword"
    end

    test "requires password" do
      attrs = %{}

      changeset = User.login_changeset(%User{}, attrs)

      refute changeset.valid?
      assert %{password: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "verify_password/2" do
    test "verifies correct password" do
      password = "Password123!"
      password_hash = Bcrypt.hash_pwd_salt(password)
      user = %User{password_hash: password_hash}

      assert User.verify_password(user, password)
    end

    test "rejects incorrect password" do
      password_hash = Bcrypt.hash_pwd_salt("correct_password")
      user = %User{password_hash: password_hash}

      refute User.verify_password(user, "wrong_password")
    end
  end

  describe "schema associations" do
    test "has correct associations defined" do
      _user = %User{}

      assert %Ecto.Association.Has{} = User.__schema__(:association, :orders)
      assert %Ecto.Association.Has{} = User.__schema__(:association, :user_products)
      assert %Ecto.Association.HasThrough{} = User.__schema__(:association, :products)
    end

    test "association cardinalities are correct" do
      orders_assoc = User.__schema__(:association, :orders)
      user_products_assoc = User.__schema__(:association, :user_products)
      products_assoc = User.__schema__(:association, :products)

      assert orders_assoc.cardinality == :many
      assert user_products_assoc.cardinality == :many
      assert products_assoc.cardinality == :many
    end

    test "products association is through user_products" do
      products_assoc = User.__schema__(:association, :products)

      assert products_assoc.through == [:user_products, :product]
    end
  end

  describe "schema metadata" do
    test "has correct primary key" do
      assert User.__schema__(:primary_key) == [:id]
    end

    test "primary key is binary_id type" do
      assert User.__schema__(:type, :id) == :binary_id
    end

    test "has correct field types" do
      assert User.__schema__(:type, :username) == :string
      assert User.__schema__(:type, :email) == :string
      # password is a virtual field, so it doesn't have a schema type
      assert User.__schema__(:type, :password) == nil
      assert User.__schema__(:type, :password_hash) == :string
      assert User.__schema__(:type, :balance) == :decimal
    end

    test "password field is virtual" do
      # Virtual fields don't appear in :fields but are defined in the schema
      fields = User.__schema__(:fields)
      refute :password in fields
    end

    test "includes timestamps" do
      fields = User.__schema__(:fields)
      assert :inserted_at in fields
      assert :updated_at in fields
    end

    test "has correct table name" do
      assert User.__schema__(:source) == "users"
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

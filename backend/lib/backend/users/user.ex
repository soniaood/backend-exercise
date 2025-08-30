defmodule Backend.Users.User do
  @moduledoc """
  Ecto schema for application users.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :username, :string
    field :email, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :balance, :decimal, default: Decimal.new("1000.00")

    has_many :orders, Backend.Orders.Order
    has_many :user_products, Backend.Users.UserProduct
    has_many :products, through: [:user_products, :product]

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :balance])
    |> validate_required([:username])
    |> validate_email()
    |> unique_constraint(:username)
    |> unique_constraint(:email)
    |> validate_number(:balance, greater_than_or_equal_to: 0)
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :password])
    |> validate_required([:username, :email, :password])
    |> validate_email()
    |> validate_password()
    |> unique_constraint(:username)
    |> unique_constraint(:email)
    |> put_change(:balance, Decimal.new("1000.00"))
    |> hash_password()
  end

  def login_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
  end

  defp validate_email(changeset) do
    changeset
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_length(:password, min: 6, max: 72)
    |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/,
      message: "at least one digit or punctuation character"
    )
  end

  defp hash_password(changeset) do
    password = get_change(changeset, :password)

    if password && changeset.valid? do
      changeset
      |> delete_change(:password)
      |> put_change(:password_hash, Bcrypt.hash_pwd_salt(password))
    else
      changeset
    end
  end

  def verify_password(user, password) do
    Bcrypt.verify_pass(password, user.password_hash)
  end

  # For frontend (create user with default balance 1000)
  def create_changeset(user, attrs) do
    user
    |> cast(attrs, [:username])
    |> validate_required([:username])
    |> unique_constraint(:username)
    |> put_change(:balance, Decimal.new("1000.00"))
  end
end

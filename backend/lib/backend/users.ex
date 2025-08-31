defmodule Backend.Users do
  @moduledoc """
  Users context.

  Exposes business operations around application users:
  — Registration and authentication
  — Retrieving users (by id and by username for Frontend prototype compatibility)
  — Managing balances
  — Querying and attaching purchased product ids via the `user_products` join

  This context is the single entry-point for user-related domain logic used by controllers and other contexts.
  """

  import Ecto.Query
  alias Backend.Repo
  alias Backend.Users.{User, UserProduct}

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def authenticate_user(username, password) do
    query = from u in User, where: u.username == ^username

    case Repo.one(query) do
      nil ->
        # Run password hash to prevent timing attacks
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      user ->
        if User.verify_password(user, password) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end
    end
  end

  def get_user(id) do
    Repo.get(User, id)
  end

  def get_user_with_products(id) do
    query =
      from u in User,
        where: u.id == ^id,
        preload: [:user_products]

    Repo.one(query)
  end

  # For Frontend prototype endpoint compatibility
  def get_user_by_username(username) do
    query =
      from u in User,
        where: u.username == ^username,
        preload: [:user_products]

    case Repo.one(query) do
      nil -> create_user(%{username: username})
      user -> {:ok, user}
    end
  end

  # For Frontend prototype endpoint compatibility
  defp create_user(attrs) do
    %User{}
    |> User.create_changeset(attrs)
    |> Repo.insert()
  end

  def update_user_balance(user, new_balance) do
    user
    |> User.changeset(%{balance: new_balance})
    |> Repo.update()
  end

  def get_user_product_ids(user) do
    query =
      from up in UserProduct,
        where: up.user_id == ^user.id,
        select: up.product_id

    Repo.all(query)
  end

  def add_user_products(user_id, product_ids, order_id) do
    user_products =
      Enum.map(product_ids, fn product_id ->
        %{
          user_id: user_id,
          product_id: product_id,
          order_id: order_id,
          inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }
      end)

    Repo.insert_all(UserProduct, user_products)
  end
end

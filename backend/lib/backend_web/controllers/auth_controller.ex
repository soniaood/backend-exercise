defmodule BackendWeb.AuthController do
  use BackendWeb, :controller
  alias Backend.{Users, Guardian}

  def register(conn, %{"user" => user_params}) do
    case Users.register_user(user_params) do
      {:ok, user} ->
        {:ok, token, _claims} = Guardian.encode_and_sign(user)

        conn
        |> put_status(:created)
        |> json(%{
          user: %{
            id: user.id,
            username: user.username,
            email: user.email
          },
          token: token
        })

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "registration_failed",
          message: "User registration failed",
          details: format_changeset_errors(changeset)
        })
    end
  end

  def login(conn, %{"username" => username, "password" => password}) do
    case Users.authenticate_user(username, password) do
      {:ok, user} ->
        {:ok, token, _claims} = Guardian.encode_and_sign(user)
        product_ids = Users.get_user_product_ids(user)

        json(conn, %{
          user: %{
            id: user.id,
            username: user.username,
            balance: user.balance,
            product_ids: product_ids
          },
          token: token
        })

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          error: "invalid_credentials",
          message: "Invalid username or password"
        })
    end
  end

  def refresh(conn, _params) do
    # Get current user from Guardian
    user = Guardian.Plug.current_resource(conn)
    {:ok, token, _claims} = Guardian.encode_and_sign(user)

    json(conn, %{token: token})
  end

  def logout(conn, _params) do
    # In a real app, you'd blacklist the token
    # For now, just return success
    json(conn, %{message: "Logged out successfully"})
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

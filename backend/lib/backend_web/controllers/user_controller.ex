defmodule BackendWeb.UserController do
  use BackendWeb, :controller
  alias Backend.Users

  # Improved API - user loaded by Guardian
  def me(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    product_ids = Users.get_user_product_ids(user)

    json(conn, %{
      username: user.username,
      email: user.email,
      balance: user.balance,
      product_ids: product_ids
    })
  end

  # For Frontend
  def get_by_username_prototype(conn, %{"username" => username}) do
    conn = put_resp_header(conn, "x-deprecated", "Use GET /api/v1/users/me with authentication")

    case Users.get_user_by_username(username) do
      {:ok, user} ->
        product_ids = Users.get_user_product_ids(user)

        response = %{
          user: %{
            user_id: user.username,
            data: %{
              balance: user.balance,
              product_ids: product_ids
            }
          }
        }

        json(conn, response)

      {:error, _changeset} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "failed_to_create_user"})
    end
  end
end

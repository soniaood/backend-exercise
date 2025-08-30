defmodule BackendWeb.OrderController do
  use BackendWeb, :controller
  alias Backend.Orders

  # New secure endpoint - /api/orders (authenticated)
  def create_authenticated(conn, %{"order" => %{"items" => items}}) do
    user = Guardian.Plug.current_resource(conn)

    case Orders.create_order(user.username, items) do
      {:ok, %{order: order, validate_balance: {products, _total}}} ->
        response = %{
          order: %{
            id: order.id,
            user_id: user.id,
            items: format_products(products),
            total: order.total,
            created_at: order.inserted_at
          }
        }

        json(conn, response)

      {:error, _step, reason, _changes} ->
        handle_order_error(conn, reason)

      {:error, reason} ->
        handle_order_error(conn, reason)
    end
  end

  # For Frontend - /orders (unauthenticated, deprecated, for backward compatibility)
  def create(conn, %{"order" => %{"items" => items, "user_id" => user_id}}) do
    conn = put_resp_header(conn, "x-deprecated", "Use POST /api/orders with authentication")

    case Orders.create_order(user_id, items) do
      {:ok, %{order: order, validate_balance: {products, _total}}} ->
        response = %{
          order: %{
            order_id: order.id,
            data: %{
              items: format_products(products),
              total: order.total
            }
          }
        }

        json(conn, response)

      {:error, _step, reason, _changes} ->
        handle_order_error(conn, reason)

      {:error, reason} ->
        handle_order_error(conn, reason)
    end
  end

  defp format_products(products) do
    Enum.map(products, fn product ->
      %{
        id: product.id,
        name: product.name,
        price: product.price
      }
    end)
  end

  defp handle_order_error(conn, reason) do
    case reason do
      :products_not_found ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "products_not_found",
          message: "One or more products were not found"
        })

      :products_already_purchased ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "products_already_purchased",
          message: "User has already purchased one or more of these products"
        })

      :insufficient_balance ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "insufficient_balance",
          message: "User balance is insufficient for this order"
        })

      _ ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error: "internal_server_error",
          message: "An unexpected error occurred"
        })
    end
  end
end

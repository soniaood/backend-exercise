defmodule BackendWeb.OrderController do
  use BackendWeb, :controller
  alias Backend.{Orders, Products, Users}

  # New secure endpoint - /api/orders (authenticated)
  def create(conn, %{"items" => items}) do
    user = Guardian.Plug.current_resource(conn)


    case Orders.create_order(user.id, items) do
      {:ok, %{order: order, validate_balance: {products, _total}}} ->
        json(conn, %{
          id: order.id,
          items: format_products(products),
          total: order.total,
          created_at: order.inserted_at
        })

      {:error, _step, reason, _changes} ->
        handle_order_error(conn, reason)
    end
  end

  # For Frontend - /orders (unauthenticated, deprecated, for backward compatibility)
  def create_prototype(conn, %{"order" => %{"items" => items, "user_id" => username}}) do
    conn = put_resp_header(conn, "x-deprecated", "Use POST /api/orders with authentication")

    # In legacy API, user_id is actually the username - need to get the actual user ID
    case Users.get_user_by_username(username) do
      {:ok, user} ->
        # Convert product names to UUIDs for the Orders context
        products = Products.get_products_by_names(items)
        if length(products) != length(items) do
          handle_order_error(conn, :products_not_found)
        else
          product_ids = Enum.map(products, & &1.id)
          
          case Orders.create_order(user.id, product_ids) do
            {:ok, %{order: order, validate_balance: {products, _total}}} ->
              response = %{
                order: %{
                  order_id: order.id,
                  data: %{
                    items: format_products_prototype(products),
                    total: order.total
                  }
                }
              }

              json(conn, response)

            {:error, _step, reason, _changes} ->
              handle_order_error(conn, reason)
          end
        end

      {:error, :user_not_found} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "user_not_found", 
          message: "User not found"
        })
    end
  end

  defp format_products_prototype(products) do
    Enum.map(products, fn product ->
      %{
        id: product.name,  # For compatibility: return name as "id"
        name: product.description,  # For compatibility: return description as "name"
        price: product.price
      }
    end)
  end

  defp format_products(products) do
    Enum.map(products, fn product ->
      %{
        id: product.id,
        name: product.name,
        description: product.description,
        price: product.price
      }
    end)
  end

  defp handle_order_error(conn, reason) do
    case reason do
      :empty_product_list ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "invalid_request",
          message: "Items list cannot be empty"
        })

      :invalid_product_list ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "invalid_request",
          message: "Items must be provided as a list"
        })

      :duplicate_products_in_request ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "duplicate_products",
          message: "Cannot order the same product multiple times in one request"
        })

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

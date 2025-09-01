defmodule BackendWeb.ProductController do
  use BackendWeb, :controller
  alias Backend.Products

  # Upgraded API endpoint
  def index(conn, _params) do
    products = Products.list_products()

    json(
      conn,
      Enum.map(products, fn product ->
        %{
          id: product.id,
          name: product.name,
          description: product.description,
          price: product.price
        }
      end)
    )
  end

  # For Frontend
  def index_prototype(conn, _params) do
    conn = put_resp_header(conn, "x-deprecated", "Use GET /api/v1/products")
    products = Products.list_products()

    # Legacy response format for compatibility - show name as "id"
    response = %{
      products:
        Enum.map(products, fn product ->
          %{
            # Legacy: name field becomes "id" for compatibility
            id: product.name,
            # Legacy: description becomes display "name"
            name: product.description,
            price: product.price
          }
        end)
    }

    json(conn, response)
  end
end

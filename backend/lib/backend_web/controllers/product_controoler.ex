# lib/backend_web/controllers/product_controller.ex
defmodule BackendWeb.ProductController do
  use BackendWeb, :controller
  alias Backend.Products

  # Modern API endpoint - /api/products
  def index(conn, _params) do
    products = Products.list_products()

    response = %{
      products:
        Enum.map(products, fn product ->
          %{
            id: product.id,
            name: product.name,
            price: product.price
          }
        end)
    }

    json(conn, response)
  end

  # For Frontend - /products
  def index_legacy(conn, _params) do
    conn = put_resp_header(conn, "x-deprecated", "Use GET /api/products")

    # Same response format for compatibility
    index(conn, %{})
  end
end

defmodule BackendWeb.AuthErrorHandler do
  @moduledoc """
  Authentication error handler plug.

  Formats authentication/authorization failures into consistent JSON responses
  (e.g., 401 Unauthorized) consumed by API clients. Intended for use with Guardian
  and the application router pipelines.
  """

  import Plug.Conn
  import Phoenix.Controller

  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, _reason}, _opts) do
    body = to_string(type)

    conn
    |> put_status(:unauthorized)
    |> put_resp_content_type("application/json")
    |> json(%{error: body, message: "Authentication required"})
  end
end

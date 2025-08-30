defmodule BackendWeb.Router do
  use BackendWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug, origin: ["http://localhost:3000"]
  end

  pipeline :authenticated do
    plug Guardian.Plug.Pipeline,
      module: Backend.Guardian,
      error_handler: BackendWeb.AuthErrorHandler

    plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
    plug Guardian.Plug.EnsureAuthenticated
    plug Guardian.Plug.LoadResource
  end

  scope "/api", BackendWeb do
    pipe_through :api

    # Authentication
    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login

    # Public endpoints
    get "/products", ProductController, :index
  end

  scope "/api", BackendWeb do
    pipe_through [:api, :authenticated]

    get "/users/me", UserController, :me
    post "/auth/refresh", AuthController, :refresh
    post "/auth/logout", AuthController, :logout

    post "/orders", OrderController, :create_authenticated
  end

  # Legacy endpoints for frontend compatibility
  scope "/", BackendWeb do
    pipe_through :api

    get "/products", ProductController, :index_legacy
    get "/users/:username", UserController, :get_by_username
    post "/orders", OrderController, :create
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:backend, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: BackendWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

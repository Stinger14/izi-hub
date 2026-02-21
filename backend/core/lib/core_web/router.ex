defmodule CoreWeb.Router do
  import Phoenix.LiveView.Router
  use CoreWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", CoreWeb do
    pipe_through :api
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CoreWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", CoreWeb do
    pipe_through :browser

    live "/welcome", HubLandingLive, :index
    live "/hub", HubLive, :index
    live "/contributions", ContributionsLive, :index
    live "/resources", ResourcesLive, :index
    live "/profile", ProfileLive, :index
    live "/notebooks", NotebooksLive, :index
    live "/notebooks/:slug", NotebooksLive, :show
    live "/liveapps", LiveAppsLive, :index
    get "/", RedirectController, :to_welcome
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:core, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:browser]

      live_dashboard "/dashboard", metrics: CoreWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

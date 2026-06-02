defmodule CoreWeb.Router do
  use CoreWeb, :router
  import Phoenix.LiveView.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :browser_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug CoreWeb.UserAuth, :fetch_current_scope
    plug CoreWeb.UserAuth, :require_authenticated_api_user
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CoreWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug CoreWeb.UserAuth, :fetch_current_scope
  end

  pipeline :require_admin do
    plug CoreWeb.UserAuth, :require_admin_user
  end

  scope "/api", CoreWeb do
    pipe_through :api
  end

  scope "/api", CoreWeb do
    pipe_through :browser_api

    post "/finance/email-ingestions", Api.Finance.EmailIngestionController, :create
  end

  scope "/", CoreWeb do
    pipe_through :browser

    get "/signup", RegistrationController, :new
    post "/signup", RegistrationController, :create
    get "/set-password", PasswordSetupController, :new
    post "/set-password", PasswordSetupController, :create
    get "/login", SessionController, :new
    post "/login", SessionController, :create
    delete "/logout", SessionController, :delete

    get "/cv", CVController, :download
    get "/", RedirectController, :to_welcome

    live_session :default,
      on_mount: [
        {CoreWeb.UserAuth, :mount_current_scope},
        {CoreWeb.UserAuth, :track_site_presence}
      ] do
      live "/welcome", HubLandingLive, :index
      live "/hub", HubLive, :index
      live "/contributions", ContributionsLive, :index
      live "/resources", UnderDevelopmentLive, :resources
      live "/profile", ProfileLive, :index
      live "/notebooks", NotebooksLive, :index
      live "/notebooks/:slug", NotebooksLive, :show
      live "/liveapps", UnderDevelopmentLive, :liveapps
    end

    live_session :authenticated,
      on_mount: [
        {CoreWeb.UserAuth, :mount_current_scope},
        {CoreWeb.UserAuth, :ensure_authenticated},
        {CoreWeb.UserAuth, :track_site_presence}
      ] do
      live "/office", OfficeLive, :index
      live "/office/:slug", OfficeLive, :show
      live "/finance", FinanceLive, :index
    end
  end

  scope "/admin", CoreWeb.Admin do
    pipe_through [:browser, :require_admin]

    live_session :admin,
      on_mount: [
        {CoreWeb.UserAuth, :mount_current_scope},
        {CoreWeb.UserAuth, :ensure_admin},
        {CoreWeb.UserAuth, :track_site_presence}
      ] do
      live "/", DashboardLive, :index
      live "/finops", FinOpsLive, :index
      live "/ops", OpsLive, :index
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:core, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:browser]

      live_dashboard "/dashboard", metrics: CoreWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

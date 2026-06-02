defmodule CoreWeb.UserAuth do
  import Plug.Conn
  import Phoenix.Controller

  use CoreWeb, :verified_routes

  alias Core.Accounts
  alias Core.Accounts.Scope
  alias CoreWeb.Presence

  @presence_topic "site:presence"

  def init(action), do: action

  def call(conn, :fetch_current_scope), do: fetch_current_scope(conn, [])
  def call(conn, :require_authenticated_user), do: require_authenticated_user(conn, [])
  def call(conn, :require_authenticated_api_user), do: require_authenticated_api_user(conn, [])
  def call(conn, :require_admin_user), do: require_admin_user(conn, [])

  def fetch_current_scope(conn, _opts) do
    conn = ensure_analytics_session_id(conn)

    scope =
      conn
      |> get_session(:user_id)
      |> case do
        nil ->
          nil

        user_id ->
          user_id
          |> Accounts.get_user()
          |> Scope.for_user()
      end

    assign(conn, :current_scope, scope)
  end

  def require_admin_user(conn, _opts) do
    cond do
      Scope.admin?(conn.assigns.current_scope) ->
        conn

      is_nil(conn.assigns.current_scope) ->
        conn
        |> put_flash(:error, "Please sign in to continue")
        |> redirect(to: ~p"/hub?auth=login")
        |> halt()

      true ->
        conn
        |> put_flash(:error, "Not authorized")
        |> redirect(to: ~p"/hub")
        |> halt()
    end
  end

  def require_authenticated_user(conn, _opts) do
    if is_nil(conn.assigns.current_scope) do
      conn
      |> put_flash(:error, "Please sign in to continue")
      |> redirect(to: ~p"/hub?auth=login")
      |> halt()
    else
      conn
    end
  end

  def require_authenticated_api_user(conn, _opts) do
    if is_nil(conn.assigns.current_scope) do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "unauthenticated"})
      |> halt()
    else
      conn
    end
  end

  def on_mount(:mount_current_scope, _params, session, socket) do
    scope =
      case Map.get(session, "user_id") || Map.get(session, :user_id) do
        nil ->
          nil

        user_id ->
          user_id
          |> Accounts.get_user()
          |> Scope.for_user()
      end

    {:cont, Phoenix.Component.assign(socket, :current_scope, scope)}
  end

  def on_mount(:track_site_presence, _params, session, socket) do
    if Phoenix.LiveView.connected?(socket) do
      _ =
        Presence.track(self(), @presence_topic, presence_key(session), %{
          joined_at: System.system_time(:second),
          live_view: inspect(socket.view),
          user_id: session_user_id(session)
        })
    end

    {:cont, socket}
  end

  def on_mount(:ensure_authenticated, _params, _session, socket) do
    if is_nil(socket.assigns.current_scope) do
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Please sign in to continue")
       |> Phoenix.LiveView.redirect(to: ~p"/hub?auth=login")}
    else
      {:cont, socket}
    end
  end

  def on_mount(:ensure_admin, _params, _session, socket) do
    cond do
      Scope.admin?(socket.assigns.current_scope) ->
        {:cont, socket}

      is_nil(socket.assigns.current_scope) ->
        {:halt,
         socket
         |> Phoenix.LiveView.put_flash(:error, "Please sign in to continue")
         |> Phoenix.LiveView.redirect(to: ~p"/hub?auth=login")}

      true ->
        {:halt,
         socket
         |> Phoenix.LiveView.put_flash(:error, "Not authorized")
         |> Phoenix.LiveView.redirect(to: ~p"/hub")}
    end
  end

  defp ensure_analytics_session_id(conn) do
    case get_session(conn, :analytics_session_id) do
      nil ->
        put_session(conn, :analytics_session_id, Ecto.UUID.generate())

      _session_id ->
        conn
    end
  end

  defp presence_key(session) do
    analytics_session_id =
      Map.get(session, "analytics_session_id") || Map.get(session, :analytics_session_id)

    case session_user_id(session) do
      nil when is_binary(analytics_session_id) ->
        "anon:" <> analytics_session_id

      nil ->
        "anon:" <> Integer.to_string(System.unique_integer([:positive]))

      user_id ->
        "user:" <> to_string(user_id)
    end
  end

  defp session_user_id(session) do
    Map.get(session, "user_id") || Map.get(session, :user_id)
  end
end

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

  @doc """
  Signs the user in: issues a server-side session token and stores it, with
  the LiveView socket id used to disconnect this session later, in a fresh
  session cookie.
  """
  def log_in_user(conn, user) do
    {token, token_id} = Accounts.generate_user_session_token(user)

    conn
    |> configure_session(renew: true)
    |> delete_session(:user_id)
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, Accounts.session_socket_id(token_id))
  end

  @doc """
  Where to go right after signing in or setting a password: back to a
  household invitation opened while signed out (`remember_invitation/2`),
  otherwise `default`. Clears the remembered invitation.
  """
  def after_sign_in_path(conn, default) do
    case get_session(conn, :pending_invite) do
      token when is_binary(token) ->
        {delete_session(conn, :pending_invite), ~p"/invites/#{token}"}

      _ ->
        {conn, default}
    end
  end

  @doc "Remembers an invitation link so sign-in or signup can return to it."
  def remember_invitation(conn, token), do: put_session(conn, :pending_invite, token)

  @doc "Signs out this browser: revokes its token and drops its open LiveViews."
  def log_out_user(conn) do
    conn |> get_session(:user_token) |> Accounts.delete_user_session_token()
    configure_session(conn, drop: true)
  end

  def fetch_current_scope(conn, _opts) do
    conn = ensure_analytics_session_id(conn)

    case conn |> get_session(:user_token) |> Accounts.get_user_by_session_token() do
      nil ->
        conn
        |> clear_stale_sign_in()
        |> assign(:current_scope, nil)

      user ->
        assign(conn, :current_scope, Scope.for_user(user))
    end
  end

  # A revoked/expired token, or a cookie from before session tokens (it held
  # only `user_id`), means signed out; drop the leftovers.
  defp clear_stale_sign_in(conn) do
    if get_session(conn, :user_token) || get_session(conn, :user_id) do
      conn
      |> delete_session(:user_token)
      |> delete_session(:user_id)
      |> delete_session(:live_socket_id)
    else
      conn
    end
  end

  def require_admin_user(conn, _opts) do
    cond do
      Scope.admin?(conn.assigns.current_scope) ->
        conn

      is_nil(conn.assigns.current_scope) ->
        conn
        |> put_flash(:error, "Please sign in to continue")
        |> redirect(to: ~p"/login?error=auth")
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
      |> redirect(to: ~p"/login?error=auth")
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
      session
      |> Map.get("user_token")
      |> Accounts.get_user_by_session_token()
      |> Scope.for_user()

    {:cont, Phoenix.Component.assign(socket, :current_scope, scope)}
  end

  def on_mount(:track_site_presence, _params, session, socket) do
    if Phoenix.LiveView.connected?(socket) do
      user_id = scope_user_id(socket.assigns[:current_scope])

      _ =
        Presence.track(self(), @presence_topic, presence_key(session, user_id), %{
          joined_at: System.system_time(:second),
          live_view: inspect(socket.view),
          user_id: user_id
        })
    end

    {:cont, socket}
  end

  def on_mount(:ensure_authenticated, _params, _session, socket) do
    if is_nil(socket.assigns.current_scope) do
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Please sign in to continue")
       |> Phoenix.LiveView.redirect(to: ~p"/login?error=auth")}
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
         |> Phoenix.LiveView.redirect(to: ~p"/login?error=auth")}

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

  defp presence_key(session, user_id) do
    analytics_session_id =
      Map.get(session, "analytics_session_id") || Map.get(session, :analytics_session_id)

    case user_id do
      nil when is_binary(analytics_session_id) ->
        "anon:" <> analytics_session_id

      nil ->
        "anon:" <> Integer.to_string(System.unique_integer([:positive]))

      user_id ->
        "user:" <> to_string(user_id)
    end
  end

  defp scope_user_id(%Scope{user: user}), do: user.id
  defp scope_user_id(_scope), do: nil
end

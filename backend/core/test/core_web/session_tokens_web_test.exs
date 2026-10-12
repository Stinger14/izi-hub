defmodule CoreWeb.SessionTokensWebTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.Accounts

  setup do
    %{user: user_fixture()}
  end

  test "signing in sets a 60-day cookie", %{conn: conn, user: user} do
    conn =
      post(conn, ~p"/login", %{"user" => %{"email" => user.email, "password" => valid_password()}})

    assert conn.resp_cookies["_core_key"].max_age == Accounts.session_validity_in_seconds()
  end

  test "an inactive user can't sign in", %{conn: conn, user: user} do
    {:ok, _} = Accounts.set_user_active(user, false)

    conn =
      post(conn, ~p"/login", %{"user" => %{"email" => user.email, "password" => valid_password()}})

    assert html_response(conn, 422) =~ "Invalid login or password"
  end

  test "a cookie from before session tokens (user_id only) is signed out", %{
    conn: conn,
    user: user
  } do
    conn = conn |> init_test_session(%{user_id: user.id}) |> get(~p"/settings")
    assert redirected_to(conn) =~ "/login"
    assert get_session(conn, :user_id) == nil
  end

  test "a revoked session is signed out on its next request", %{conn: conn, user: user} do
    conn = log_in_user(conn, user)
    Accounts.revoke_user_sessions(user)
    assert {:error, {:redirect, %{to: to}}} = live(conn, ~p"/settings")
    assert to =~ "/login"
  end

  # LiveViewTest has no real socket, so these assert the "disconnect" reaches
  # the session's socket topic; Phoenix.LiveView.Socket uses that
  # `live_socket_id` as its id and closes on it.
  defp watch_socket(conn) do
    :ok = Phoenix.PubSub.subscribe(Core.PubSub, get_session(conn, :live_socket_id))
    conn
  end

  defp assert_disconnected do
    assert_receive %Phoenix.Socket.Broadcast{event: "disconnect"}
  end

  test "logging out disconnects that browser's open pages", %{conn: conn, user: user} do
    conn = conn |> log_in_user(user) |> watch_socket()
    delete(conn, ~p"/logout")
    assert_disconnected()
  end

  test "deactivating a user disconnects their open pages", %{conn: conn, user: user} do
    conn |> log_in_user(user) |> watch_socket()
    {:ok, _} = Accounts.set_user_active(user, false)
    assert_disconnected()
  end

  test "Sign out everywhere else keeps this session and drops the others", %{
    conn: conn,
    user: user
  } do
    build_conn() |> log_in_user(user) |> watch_socket()
    conn = log_in_user(conn, user)
    this_token = get_session(conn, :user_token)

    {:ok, view, _html} = live(conn, ~p"/settings")

    assert view |> element("#sign-out-other-sessions") |> render_click() =~
             "Signed out of 1 other device"

    assert_disconnected()
    assert Accounts.get_user_by_session_token(this_token)
  end
end

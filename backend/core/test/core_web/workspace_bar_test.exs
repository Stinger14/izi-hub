defmodule CoreWeb.WorkspaceBarTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "every signed-in page gets the bar with its own app highlighted", %{conn: conn} do
    conn = log_in_user(conn, user_fixture())

    for {path, key} <- [{~p"/finance", "finance"}, {~p"/office", "office"}] do
      {:ok, view, _html} = live(conn, path)

      assert has_element?(view, "#workspace-nav-#{key}[aria-current=page]")
      assert has_element?(view, "#workspace-nav-hub[href='/hub']")
      assert has_element?(view, "#workspace-pages")
      refute has_element?(view, "#workspace-bar button", "Translate")
      refute has_element?(view, "#workspace-nav-admin")
    end

    {:ok, view, _html} = live(conn, ~p"/settings")
    assert has_element?(view, "#workspace-bar")
    refute has_element?(view, "#workspace-bar [aria-current=page]")
  end

  test "the header is the logo beside the strip: apps, then the account menu", %{
    conn: conn
  } do
    {:ok, view, _html} = live(log_in_user(conn, user_fixture()), ~p"/hub")

    assert has_element?(view, "#site-header #workspace-bar #workspace-nav-office")
    assert has_element?(view, "#site-header #account-menu-trigger")
    assert has_element?(view, "#site-header a#header-logo[href='/hub']", "IziHub")
    refute has_element?(view, "#workspace-bar #header-logo")
    refute has_element?(view, "#site-header > * > form button", "Logout")
  end

  test "admins also get Admin, highlighted on admin pages", %{conn: conn} do
    {:ok, view, _html} = live(log_in_user(conn, admin_fixture()), ~p"/admin")

    assert has_element?(view, "#workspace-nav-admin[aria-current=page]")
  end

  test "signed-out visitors get the logo and Sign in, without apps", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/welcome")

    assert has_element?(view, "#site-header a#header-logo[href='/welcome']", "IziHub")
    assert has_element?(view, "#header-sign-in")
    refute has_element?(view, "#workspace-nav-hub")
    refute has_element?(view, "#account-menu")
  end
end

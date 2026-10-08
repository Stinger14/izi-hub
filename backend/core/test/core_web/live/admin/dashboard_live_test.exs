defmodule CoreWeb.Admin.DashboardLiveTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.Analytics

  test "redirects unauthenticated users to login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/login?error=auth"}}} = live(conn, ~p"/admin")
  end

  test "redirects non-admin users", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)

    assert {:error, {:redirect, %{to: "/hub"}}} = live(conn, ~p"/admin")
  end

  test "renders admin dashboard metrics for admins", %{conn: conn} do
    admin = admin_fixture()
    conn = init_test_session(conn, user_id: admin.id)
    {:ok, _} = Analytics.record_page_view(%{page_path: "/cv/download", session_id: "session-a"})
    {:ok, _} = Analytics.record_page_view(%{page_path: "/cv/download", session_id: "session-b"})

    assert {:ok, _view, html} = live(conn, ~p"/admin")

    assert html =~ "Admin dashboard"
    assert html =~ "CV Downloads"
    assert html =~ "Online Now"
    assert html =~ "Analytics"
    assert html =~ "FinOps"
    assert html =~ "2"
  end
end

defmodule CoreWeb.Admin.DashboardLiveTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.Accounts
  alias Core.Analytics

  test "renders admin dashboard metrics", %{conn: conn} do
    assert {:ok, _view, html} = live(conn, ~p"/admin")

    assert html =~ "Admin dashboard"
    assert html =~ "CV Downloads"
    assert html =~ "Online Now"
  end

  test "shows CV download totals and users", %{conn: conn} do
    {:ok, _} =
      Accounts.register_user(%{
        email: "admin_dashboard_user@example.com",
        password: "Password123!",
        username: "admin_dashboard_user",
        full_name: "Admin Dashboard User"
      })

    {:ok, _} = Analytics.record_page_view(%{page_path: "/cv/download", session_id: "session-a"})
    {:ok, _} = Analytics.record_page_view(%{page_path: "/cv/download", session_id: "session-b"})

    assert {:ok, _view, html} = live(conn, ~p"/admin")

    assert html =~ "2"
    assert html =~ "admin_dashboard_user"
  end
end

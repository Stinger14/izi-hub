defmodule CoreWeb.Admin.DashboardLiveTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.Accounts
  alias Core.Analytics
  alias Core.Repo

  test "redirects unauthenticated users to login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/hub?auth=login"}}} = live(conn, ~p"/admin")
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

  defp user_fixture do
    {:ok, user} =
      Accounts.register_user(%{
        email: "dashboard_user_#{System.unique_integer([:positive])}@example.com",
        password: "Password123!",
        username: "dashboard_user_#{System.unique_integer([:positive])}",
        full_name: "Dashboard User"
      })

    user
  end

  defp admin_fixture do
    user = user_fixture()

    user
    |> Ecto.Changeset.change(%{role: "admin", is_active: true})
    |> Repo.update!()
  end
end

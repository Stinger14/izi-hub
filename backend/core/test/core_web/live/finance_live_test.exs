defmodule CoreWeb.FinanceLiveTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.Accounts

  test "redirects unauthenticated users to login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/hub?auth=login"}}} = live(conn, ~p"/finance")
  end

  test "renders the finance dashboard for authenticated users", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)

    assert {:ok, _view, html} = live(conn, ~p"/finance")

    assert html =~ "IziFinance"
    assert html =~ "Debt consolidation studio"
    assert html =~ "Snowball vs avalanche"
    assert html =~ "Current income"
  end

  defp user_fixture do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        email: "finance_live_user_#{unique}@example.com",
        password: "Password123!",
        username: "finance_live_user_#{unique}",
        full_name: "Finance Live User"
      })

    user
  end
end

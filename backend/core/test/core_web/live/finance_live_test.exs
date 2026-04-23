defmodule CoreWeb.FinanceLiveTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.Accounts
  alias Core.Finance

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

  test "records a debt payment from the finance dashboard", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)

    {:ok, debt} =
      Finance.create_debt(user, %{
        "name" => "Rewards card",
        "kind" => "credit_card",
        "current_balance" => "300.00",
        "minimum_payment" => "25.00"
      })

    {:ok, view, _html} = live(conn, ~p"/finance")

    html =
      view
      |> element("button[phx-click=\"open_payment_form\"][phx-value-id=\"#{debt.id}\"]")
      |> render_click()

    assert html =~ "Payment amount"

    html =
      view
      |> form("form[phx-submit=\"record_payment\"]",
        debt_id: debt.id,
        payment: %{
          "amount" => "75.00",
          "payment_date" => "2026-04-12",
          "kind" => "extra",
          "notes" => "LiveView payment",
          "create_expense_transaction" => "true"
        }
      )
      |> render_submit()

    assert html =~ "$225.00"
    assert html =~ "Recent payments"

    updated_debt = Finance.get_debt_for_user!(user, debt.id)
    assert updated_debt.current_balance == Decimal.new("225.00")
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

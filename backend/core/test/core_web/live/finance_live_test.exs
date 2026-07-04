defmodule CoreWeb.FinanceLiveTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.Accounts
  alias Core.Accounts.Household
  alias Core.Finance

  test "redirects unauthenticated users to login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/hub?auth=login"}}} = live(conn, ~p"/finance")
  end

  test "renders the finance dashboard for authenticated users", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)

    assert {:ok, _view, html} = live(conn, ~p"/finance")

    assert html =~ "account"
    assert html =~ "Household coming soon"
    assert html =~ "Available cash"
    assert html =~ "Manage personal finances"
  end

  test "creates a manual transaction from the dashboard", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)
    today = Date.utc_today()

    {:ok, category} = Finance.create_category(user, %{"name" => "Salary", "type" => "income"})
    {:ok, view, _html} = live(conn, ~p"/finance")

    view
    |> element("button", "Add expense")
    |> render_click()

    html =
      view
      |> form("form[phx-submit=\"create_transaction\"]",
        transaction: %{
          "amount" => "3200.00",
          "type" => "income",
          "description" => "April salary",
          "transaction_date" => Date.to_iso8601(today),
          "payment_method" => "bank_transfer",
          "category_id" => category.id
        }
      )
      |> render_submit()

    assert html =~ "April salary"
    assert html =~ "+$3200.00"

    [transaction] = Finance.list_transactions_for_user(user)
    assert transaction.description == "April salary"
  end

  test "creates a budget and shows active budget status", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)
    today = Date.utc_today()
    month_start = Date.beginning_of_month(today)

    {:ok, category} = Finance.create_category(user, %{"name" => "Groceries", "type" => "expense"})

    {:ok, _transaction} =
      Finance.create_transaction(user, %{
        "amount" => "75.00",
        "type" => "expense",
        "description" => "Market",
        "transaction_date" => Date.to_iso8601(today),
        "category_id" => category.id
      })

    {:ok, view, _html} = live(conn, ~p"/finance")

    view
    |> element("button", "Create budget")
    |> render_click()

    html =
      view
      |> form("form[phx-submit=\"create_budget\"]",
        budget: %{
          "name" => "Groceries",
          "amount" => "300.00",
          "period" => "monthly",
          "start_date" => Date.to_iso8601(month_start),
          "alert_threshold" => "80",
          "category_id" => category.id
        }
      )
      |> render_submit()

    assert html =~ "$75.00"
    assert html =~ "$225.00"
  end

  test "review queue confirms a pending transaction", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)
    today = Date.utc_today()

    {:ok, transaction} =
      Finance.create_transaction(user, %{
        "amount" => "54.25",
        "type" => "expense",
        "description" => "Card alert",
        "merchant" => "Cafe Central",
        "transaction_date" => Date.to_iso8601(today),
        "status" => "pending_review",
        "source" => "email",
        "review_reason" => "Matched subject"
      })

    {:ok, view, _html} = live(conn, ~p"/finance")

    view
    |> element("button", "Open review queue")
    |> render_click()

    html =
      view
      |> element("button[phx-click=\"confirm_transaction\"][phx-value-id=\"#{transaction.id}\"]")
      |> render_click()

    refute html =~ "Cafe Central"
    assert Finance.get_transaction_for_user!(user, transaction.id).status == "confirmed"
  end

  test "editing a pending transaction confirms it", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)
    today = Date.utc_today()

    {:ok, transaction} =
      Finance.create_transaction(user, %{
        "amount" => "18.50",
        "type" => "expense",
        "description" => "Raw import",
        "transaction_date" => Date.to_iso8601(today),
        "status" => "pending_review",
        "source" => "email"
      })

    {:ok, view, _html} = live(conn, ~p"/finance")

    view
    |> element("button", "Open review queue")
    |> render_click()

    html =
      view
      |> element(
        "button[phx-click=\"open_edit_transaction\"][phx-value-id=\"#{transaction.id}\"]"
      )
      |> render_click()

    assert html =~ "Save and confirm"

    html =
      view
      |> form("form[phx-submit=\"update_transaction\"]",
        transaction: %{
          "amount" => "18.50",
          "type" => "expense",
          "description" => "Taxi",
          "transaction_date" => Date.to_iso8601(today),
          "payment_method" => "card",
          "category_id" => ""
        }
      )
      |> render_submit()

    assert html =~ "Taxi"

    updated_transaction = Finance.get_transaction_for_user!(user, transaction.id)
    assert updated_transaction.status == "confirmed"
    assert updated_transaction.description == "Taxi"
  end

  test "review queue can ignore a pending transaction", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)
    today = Date.utc_today()

    {:ok, transaction} =
      Finance.create_transaction(user, %{
        "amount" => "11.00",
        "type" => "expense",
        "description" => "Noise",
        "transaction_date" => Date.to_iso8601(today),
        "status" => "pending_review",
        "source" => "email"
      })

    {:ok, view, _html} = live(conn, ~p"/finance")

    view
    |> element("button", "Open review queue")
    |> render_click()

    html =
      view
      |> element("button[phx-click=\"ignore_transaction\"][phx-value-id=\"#{transaction.id}\"]")
      |> render_click()

    refute html =~ "Noise"
    assert Finance.get_transaction_for_user!(user, transaction.id).status == "ignored"
  end

  test "records a debt payment from the finance dashboard", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)
    today = Date.utc_today()

    {:ok, debt} =
      Finance.create_debt(user, %{
        "name" => "Rewards card",
        "kind" => "credit_card",
        "current_balance" => "300.00",
        "minimum_payment" => "25.00"
      })

    {:ok, view, _html} = live(conn, ~p"/finance")

    view
    |> element("button", "Manage debt")
    |> render_click()

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
          "payment_date" => Date.to_iso8601(today),
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

  test "switches to a household workspace without showing personal finance data", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)
    today = Date.utc_today()

    {:ok, %Household{} = household} = Accounts.create_household(user, %{"name" => "Garcia Home"})

    {:ok, _transaction} =
      Finance.create_transaction(user, %{
        "amount" => "48.00",
        "type" => "expense",
        "description" => "Private groceries",
        "transaction_date" => Date.to_iso8601(today)
      })

    {:ok, view, _html} = live(conn, ~p"/finance")

    html =
      view
      |> element("button[aria-label=\"Household finance scope\"]")
      |> render_click()

    assert html =~ household.name
    assert html =~ "Shared household finance is scoped by membership"
    refute html =~ "Private groceries"
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

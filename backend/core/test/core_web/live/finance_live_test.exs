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

    assert html =~ "IziHub Finance"
    assert html =~ "Total Balance"
    assert html =~ "+ Household"
  end

  test "creates a manual transaction from the dashboard", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)
    today = Date.utc_today()

    {:ok, category} = Finance.create_category(user, %{"name" => "Salary", "type" => "income"})

    {:ok, account} =
      Finance.create_account(user, %{
        "name" => "Main checking",
        "kind" => "checking",
        "current_balance" => "2000.00"
      })

    {:ok, view, _html} = live(conn, ~p"/finance")

    view
    |> element("button[aria-label=\"Add transaction\"]")
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
          "category_id" => category.id,
          "account_id" => account.id
        }
      )
      |> render_submit()

    assert html =~ "April salary"
    assert html =~ "+DOP$ 3,200.00"
    assert html =~ "Main checking"

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
    |> element("button[aria-label=\"Create budget\"]")
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

    assert html =~ "DOP$ 75.00"
    assert html =~ "DOP$ 225.00"
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
    |> element("button[aria-label=\"Add debt\"]")
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

    assert html =~ "DOP$ 225.00"
    assert html =~ "Recent payments"

    updated_debt = Finance.get_debt_for_user!(user, debt.id)
    assert updated_debt.current_balance == Decimal.new("225.00")
  end

  test "switches to a household workspace without showing personal finance data", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)
    today = Date.utc_today()

    {:ok, %Household{} = household} = Accounts.create_household(user, %{"name" => "Garcia Home"})

    {:ok, household_category} =
      Finance.create_category(user, household, %{
        "name" => "Shared Groceries",
        "type" => "expense"
      })

    {:ok, _transaction} =
      Finance.create_transaction(user, %{
        "amount" => "48.00",
        "type" => "expense",
        "description" => "Private groceries",
        "transaction_date" => Date.to_iso8601(today)
      })

    {:ok, _shared_transaction} =
      Finance.create_transaction(user, household, %{
        "amount" => "112.00",
        "type" => "expense",
        "description" => "House groceries",
        "transaction_date" => Date.to_iso8601(today),
        "category_id" => household_category.id
      })

    {:ok, view, _html} = live(conn, ~p"/finance")

    html =
      view
      |> element("button[aria-label=\"Household finance scope\"]")
      |> render_click()

    assert html =~ household.name
    assert html =~ "House groceries"
    refute html =~ "Private groceries"
  end

  test "opens the household panel from the header cta", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)

    {:ok, _household} = Accounts.create_household(user, %{"name" => "Garcia Home"})
    {:ok, view, _html} = live(conn, ~p"/finance")

    refute has_element?(view, "form[phx-submit=\"create_household\"]")

    html =
      view
      |> element("button[aria-label=\"Add household\"]")
      |> render_click()

    assert html =~ "Create or switch scope"
    assert html =~ "aria-label=\"Create household\""
  end

  test "creates an account from the account panel", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)

    {:ok, view, _html} = live(conn, ~p"/finance")

    html =
      view
      |> element("button[aria-label=\"Add account\"]")
      |> render_click()

    # Opens the quick-add focus panel inline (same pattern as "+ Budget"/"+
    # Debt"), rather than navigating away to the Accounts section.
    assert html =~ "Add account"
    assert html =~ ~s(value="DOP")

    html =
      view
      |> form("form[phx-submit=\"create_account\"]",
        account: %{
          "name" => "Emergency savings",
          "institution" => "Popular Bank",
          "kind" => "savings",
          "currency" => "DOP",
          "current_balance" => "1800.00",
          "available_balance" => "1800.00",
          "notes" => "Rainy day"
        }
      )
      |> render_submit()

    assert html =~ "Emergency savings"
    assert html =~ "DOP$ 1,800.00"

    [account] = Finance.list_accounts_for_user(user)
    assert account.name == "Emergency savings"
    assert account.currency == "DOP"
  end

  test "creates an account transfer between two accounts", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)

    {:ok, from_account} =
      Finance.create_account(user, %{
        "name" => "Checking",
        "kind" => "checking",
        "currency" => "DOP",
        "current_balance" => "1000.00"
      })

    {:ok, to_account} =
      Finance.create_account(user, %{
        "name" => "Savings",
        "kind" => "savings",
        "currency" => "DOP",
        "current_balance" => "200.00"
      })

    {:ok, view, _html} = live(conn, ~p"/finance")

    html =
      view
      |> form("form[phx-submit=\"create_transfer\"]",
        transfer: %{
          "from_account_id" => from_account.id,
          "to_account_id" => to_account.id,
          "amount" => "150.00"
        }
      )
      |> render_submit()

    assert html =~ "Transfer"

    updated_from = Finance.get_account!(user, user, from_account.id)
    updated_to = Finance.get_account!(user, user, to_account.id)
    assert Decimal.equal?(updated_from.current_balance, Decimal.new("850.00"))
    assert Decimal.equal?(updated_to.current_balance, Decimal.new("350.00"))
  end

  test "hero currency selector switches the displayed balance", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)

    {:ok, _dop} =
      Finance.create_account(user, %{
        "name" => "DOP checking",
        "kind" => "checking",
        "currency" => "DOP",
        "current_balance" => "1000.00"
      })

    {:ok, _usd} =
      Finance.create_account(user, %{
        "name" => "USD checking",
        "kind" => "checking",
        "currency" => "USD",
        "current_balance" => "500.00"
      })

    {:ok, view, _html} = live(conn, ~p"/finance")

    assert has_element?(view, "select[name=\"currency\"] option[value=\"DOP\"][selected]")

    html =
      view
      |> form("form[phx-change=\"select_hero_currency\"]", %{"currency" => "USD"})
      |> render_change()

    assert html =~ "US$"
    assert has_element?(view, "select[name=\"currency\"] option[value=\"USD\"][selected]")
  end

  test "hero month selector updates income for the selected month", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)
    today = Date.utc_today()
    current_month_value = Calendar.strftime(today, "%Y-%m")

    last_month_start =
      today |> Date.beginning_of_month() |> Date.add(-1) |> Date.beginning_of_month()

    last_month_value = Calendar.strftime(last_month_start, "%Y-%m")

    {:ok, _transaction} =
      Finance.create_transaction(user, %{
        "amount" => "500.00",
        "type" => "income",
        "description" => "Old salary",
        "transaction_date" => Date.to_iso8601(last_month_start)
      })

    {:ok, view, _html} = live(conn, ~p"/finance")

    assert has_element?(
             view,
             "select[name=\"month\"] option[value=\"#{current_month_value}\"][selected]"
           )

    view
    |> form("form[phx-change=\"select_hero_month\"]", %{"month" => last_month_value})
    |> render_change()

    assert has_element?(
             view,
             "select[name=\"month\"] option[value=\"#{last_month_value}\"][selected]"
           )
  end

  test "cashflow year and window selectors update the active selection", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)
    last_year = Date.utc_today().year - 1

    {:ok, view, _html} = live(conn, ~p"/finance")

    assert has_element?(view, "select[name=\"window\"] option[value=\"6\"][selected]")

    view
    |> form("form[phx-change=\"select_cashflow_year\"]", %{"year" => Integer.to_string(last_year)})
    |> render_change()

    assert has_element?(view, "select[name=\"year\"] option[value=\"#{last_year}\"][selected]")

    view
    |> form("form[phx-change=\"select_cashflow_window\"]", %{"window" => "3"})
    |> render_change()

    assert has_element?(view, "select[name=\"window\"] option[value=\"3\"][selected]")
  end

  test "filters the transactions table by type", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)
    today = Date.utc_today()

    {:ok, _income} =
      Finance.create_transaction(user, %{
        "amount" => "500.00",
        "type" => "income",
        "description" => "Paycheck",
        "transaction_date" => Date.to_iso8601(today)
      })

    {:ok, _expense} =
      Finance.create_transaction(user, %{
        "amount" => "40.00",
        "type" => "expense",
        "description" => "Groceries run",
        "transaction_date" => Date.to_iso8601(today)
      })

    {:ok, view, _html} = live(conn, ~p"/finance")

    view
    |> element("aside button[phx-value-section=\"transactions\"]")
    |> render_click()

    html =
      view
      |> form("form[phx-change=\"filter_transactions\"]", %{"filters" => %{"type" => "income"}})
      |> render_change()

    assert html =~ "Paycheck"
    refute html =~ "Groceries run"
  end

  test "sorts the transactions table by amount", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)
    today = Date.utc_today()

    {:ok, _small} =
      Finance.create_transaction(user, %{
        "amount" => "10.00",
        "type" => "expense",
        "description" => "Small purchase",
        "transaction_date" => Date.to_iso8601(today)
      })

    {:ok, _large} =
      Finance.create_transaction(user, %{
        "amount" => "90.00",
        "type" => "expense",
        "description" => "Large purchase",
        "transaction_date" => Date.to_iso8601(today)
      })

    {:ok, view, _html} = live(conn, ~p"/finance")

    view
    |> element("aside button[phx-value-section=\"transactions\"]")
    |> render_click()

    html =
      view
      |> element("button[phx-click=\"sort_transactions\"][phx-value-field=\"amount\"]")
      |> render_click()

    {small_pos, _} = :binary.match(html, "Small purchase")
    {large_pos, _} = :binary.match(html, "Large purchase")

    # First click defaults to descending, so the larger amount appears first.
    assert large_pos < small_pos
  end

  test "paginates the transactions table", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)
    today = Date.utc_today()

    for n <- 1..26 do
      {:ok, _} =
        Finance.create_transaction(user, %{
          "amount" => "#{n}.00",
          "type" => "expense",
          "description" => "TxnItem-#{String.pad_leading(Integer.to_string(n), 2, "0")}",
          "transaction_date" => Date.to_iso8601(today)
        })
    end

    {:ok, view, _html} = live(conn, ~p"/finance")

    view
    |> element("aside button[phx-value-section=\"transactions\"]")
    |> render_click()

    html =
      view
      |> element("button[phx-click=\"sort_transactions\"][phx-value-field=\"amount\"]")
      |> render_click()

    # First click defaults to descending, so amounts 26.00..2.00 fill page 1 and 1.00 lands on page 2.
    assert html =~ "26 transactions"
    assert html =~ "page 1 of 2"
    assert html =~ "TxnItem-02"
    refute html =~ "TxnItem-01"

    html =
      view
      |> element("button[phx-click=\"paginate_transactions\"][phx-value-page=\"2\"]")
      |> render_click()

    assert html =~ "page 2 of 2"
    assert html =~ "TxnItem-01"
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

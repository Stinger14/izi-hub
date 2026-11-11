defmodule CoreWeb.FinanceAccountsTest do
  @moduledoc "Account detail, balance adjustments, transfers and owed balances in FinanceLive."
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.{Finance, Repo}
  alias Core.Finance.{Account, Debt, Transaction}

  setup %{conn: conn} do
    user = user_fixture()
    checking = account!(user, "Checking", "checking", "10000")
    %{conn: log_in_user(conn, user), user: user, checking: checking}
  end

  defp account!(user, name, kind, balance, currency \\ "DOP") do
    {:ok, account} =
      Finance.create_account(user, %{
        "name" => name,
        "kind" => kind,
        "currency" => currency,
        "current_balance" => balance
      })

    account
  end

  defp balance(account), do: Repo.get!(Account, account.id).current_balance

  defp assert_balance(account, expected),
    do: assert(Decimal.equal?(balance(account), Decimal.new(expected)))

  describe "account detail" do
    test "shows the history with the balance after each transaction", %{
      conn: conn,
      user: user,
      checking: checking
    } do
      {:ok, _} =
        Finance.create_transaction(user, %{
          "type" => "expense",
          "amount" => "250",
          "transaction_date" => Date.utc_today(),
          "description" => "Groceries",
          "account_id" => checking.id
        })

      {:ok, view, _html} = live(conn, ~p"/finance")
      render_click(view, "show_section", %{"section" => "accounts"})
      html = view |> element(~s(button[title="Open Checking"])) |> render_click()

      assert html =~ ~s(id="account-detail")
      assert view |> element("#account-detail-balance") |> render() =~ "DOP$ 9,750.00"
      assert html =~ "Groceries"

      html = render_click(view, "close_account", %{})
      refute html =~ ~s(id="account-detail")
    end

    test "Adjust balance records an adjustment", %{conn: conn, checking: checking} do
      {:ok, view, _html} = live(conn, ~p"/finance?account=#{checking.id}")

      html =
        view
        |> form("#adjust-balance-form", adjustment: %{"balance" => "9800", "notes" => "Bank"})
        |> render_submit()

      assert_balance(checking, "9800")
      assert html =~ "Checking balance updated"
      assert html =~ "Adjustment"

      adjustment = Repo.get_by!(Transaction, account_id: checking.id)
      assert adjustment.balance_adjustment
      assert adjustment.notes == "Bank"
    end
  end

  describe "credit cards" do
    test "are entered and shown as the amount owed", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/finance")
      render_click(view, "show_section", %{"section" => "accounts"})

      html =
        view
        |> form("#account-section-form",
          account: %{
            "name" => "Visa",
            "kind" => "credit_card",
            "currency" => "DOP",
            "current_balance" => "5000"
          }
        )
        |> render_submit()

      [card] = Finance.list_accounts_for_user(user) |> Enum.filter(&(&1.name == "Visa"))
      assert Decimal.equal?(card.current_balance, "-5000")
      assert html =~ "Owed DOP$ 5,000.00"
    end

    test "adjusting a card takes the amount owed", %{conn: conn, user: user} do
      card = account!(user, "Visa", "credit_card", "-5000")
      {:ok, view, _html} = live(conn, ~p"/finance?account=#{card.id}")

      view
      |> form("#adjust-balance-form", adjustment: %{"balance" => "4200"})
      |> render_submit()

      assert_balance(card, "-4200")
    end
  end

  describe "transfers" do
    test "the account page prefills the transfer, with date and note", %{
      conn: conn,
      user: user,
      checking: checking
    } do
      savings = account!(user, "Savings", "savings", "0")
      {:ok, view, _html} = live(conn, ~p"/finance?account=#{checking.id}")

      view |> element("button", "Transfer out") |> render_click()

      view
      |> form("#transfer-panel-form",
        transfer: %{
          "from_account_id" => checking.id,
          "to_account_id" => savings.id,
          "amount" => "1200",
          "transaction_date" => "2026-02-03",
          "notes" => "Emergency fund"
        }
      )
      |> render_submit()

      assert_balance(checking, "8800")
      assert_balance(savings, "1200")
      leg = Repo.get_by!(Transaction, account_id: savings.id)
      assert leg.transaction_date == ~D[2026-02-03]
      assert leg.notes == "Emergency fund"
    end

    test "different currencies ask for the amount received", %{
      conn: conn,
      user: user,
      checking: checking
    } do
      usd = account!(user, "Dollars", "savings", "0", "USD")
      {:ok, view, _html} = live(conn, ~p"/finance")
      render_click(view, "open_focus_panel", %{"panel" => "transfer"})

      html =
        view
        |> form("#transfer-panel-form",
          transfer: %{"from_account_id" => checking.id, "to_account_id" => usd.id}
        )
        |> render_change(%{"transfer" => %{"amount" => "5910"}})

      assert html =~ "Amount received (USD)"

      html =
        view
        |> form("#transfer-panel-form",
          transfer: %{
            "from_account_id" => checking.id,
            "to_account_id" => usd.id,
            "amount" => "5910",
            "received_amount" => "100"
          }
        )
        |> render_submit()

      assert html =~ "Transfer recorded"
      assert_balance(checking, "4090")
      assert_balance(usd, "100")
    end

    test "editing a transfer leg opens the transfer form and moves both balances", %{
      conn: conn,
      user: user,
      checking: checking
    } do
      savings = account!(user, "Savings", "savings", "0")

      {:ok, {out_leg, _in_leg}} =
        Finance.create_account_transfer(user, user, %{
          "from_account_id" => checking.id,
          "to_account_id" => savings.id,
          "amount" => "1000"
        })

      {:ok, view, _html} = live(conn, ~p"/finance")
      html = render_click(view, "open_edit_transaction", %{"id" => out_leg.id})
      assert html =~ "Edit transfer"

      view
      |> form("#transfer-panel-form", transfer: %{"amount" => "400"})
      |> render_submit()

      assert_balance(checking, "9600")
      assert_balance(savings, "400")
    end
  end

  test "deleting a transaction asks first", %{conn: conn, user: user, checking: checking} do
    {:ok, transaction} =
      Finance.create_transaction(user, %{
        "type" => "expense",
        "amount" => "100",
        "transaction_date" => Date.utc_today(),
        "description" => "Taxi",
        "account_id" => checking.id
      })

    {:ok, view, _html} = live(conn, ~p"/finance")
    render_click(view, "show_section", %{"section" => "transactions"})

    html = view |> element(~s(button[aria-label="Delete Taxi"])) |> render_click()
    assert html =~ "Delete?"
    assert Repo.get(Transaction, transaction.id)

    view |> element(~s(button[aria-label="Confirm delete Taxi"])) |> render_click()
    refute Repo.get(Transaction, transaction.id)
    assert_balance(checking, "10000")
  end

  test "a debt can be paid from an account", %{conn: conn, user: user, checking: checking} do
    {:ok, debt} =
      Finance.create_debt(user, %{
        "name" => "Car loan",
        "kind" => "loan",
        "currency" => "DOP",
        "current_balance" => "3000",
        "minimum_payment" => "500"
      })

    {:ok, view, _html} = live(conn, ~p"/finance")
    render_click(view, "show_section", %{"section" => "debts"})
    render_click(view, "open_payment_form", %{"id" => debt.id})

    view
    |> form(~s(form[phx-submit="record_payment"]),
      payment: %{"amount" => "500", "kind" => "minimum", "account_id" => checking.id}
    )
    |> render_submit()

    assert_balance(checking, "9500")
    assert Decimal.equal?(Repo.get!(Debt, debt.id).current_balance, "2500")
  end

  test "an invalid goal re-renders its form instead of crashing", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/finance")
    render_click(view, "show_section", %{"section" => "goals"})

    html =
      view
      |> form("#goal-form", goal: %{"name" => "", "target_amount" => ""})
      |> render_submit()

    assert html =~ "can&#39;t be blank"
  end
end

defmodule CoreWeb.FinanceEditingTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.{Finance, Repo}
  alias Core.Finance.{Account, Budget, Category, Debt, SavingsGoal}

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  defp open(conn, section) do
    {:ok, view, _html} = live(conn, ~p"/finance")
    render_click(view, "show_section", %{"section" => section})
    view
  end

  defp click(view, selector), do: view |> element(selector) |> render_click()

  describe "accounts" do
    setup %{user: user} do
      {:ok, account} =
        Finance.create_account(user, %{
          "name" => "Checking",
          "kind" => "checking",
          "current_balance" => "100"
        })

      %{account: account}
    end

    test "edits an account in the section form", %{conn: conn, account: account} do
      view = open(conn, "accounts")
      html = click(view, ~s(button[aria-label="Edit Checking"]))
      assert html =~ "Edit account"

      view
      |> form("#account-section-form", account: %{"name" => "Main checking"})
      |> render_submit()

      assert Repo.get!(Account, account.id).name == "Main checking"
      refute render(view) =~ "Edit account"
    end

    test "archives and restores an account", %{conn: conn, account: account} do
      view = open(conn, "accounts")
      click(view, ~s(button[aria-label="Archive Checking"]))
      assert Repo.get!(Account, account.id).status == "archived"

      click(view, "button[phx-click=toggle_archived_accounts]")
      html = click(view, ~s(button[aria-label="Restore Checking"]))
      assert Repo.get!(Account, account.id).status == "active"
      assert html =~ "Account restored"
    end

    test "deletes an empty account only after confirming", %{conn: conn, account: account} do
      view = open(conn, "accounts")
      html = click(view, ~s(button[aria-label="Delete Checking"]))
      assert html =~ "Delete “Checking”?"
      assert Repo.get(Account, account.id)

      click(view, ~s(button[aria-label="Confirm delete Checking"]))
      refute Repo.get(Account, account.id)
    end

    test "offers no delete for an account with transactions", %{
      conn: conn,
      user: user,
      account: account
    } do
      {:ok, _} =
        Finance.create_transaction(user, %{
          "amount" => "5",
          "type" => "expense",
          "transaction_date" => Date.to_iso8601(Date.utc_today()),
          "account_id" => account.id
        })

      view = open(conn, "accounts")
      assert has_element?(view, ~s(button[aria-label="Archive Checking"]))
      refute has_element?(view, ~s(button[aria-label="Delete Checking"]))
    end
  end

  test "edits and deletes a budget", %{conn: conn, user: user} do
    {:ok, budget} =
      Finance.create_budget(user, %{
        "name" => "Groceries",
        "amount" => "400",
        "period" => "monthly",
        "start_date" => Date.to_iso8601(Date.beginning_of_month(Date.utc_today()))
      })

    view = open(conn, "budgets")
    html = click(view, ~s(button[aria-label="Edit Groceries"]))
    assert html =~ "Edit budget"

    view |> form("#budget-form", budget: %{"amount" => "450"}) |> render_submit()
    assert Decimal.equal?(Repo.get!(Budget, budget.id).amount, "450")

    click(view, ~s(button[aria-label="Delete Groceries"]))
    click(view, ~s(button[aria-label="Confirm delete Groceries"]))
    refute Repo.get(Budget, budget.id)
  end

  test "edits and deletes a category", %{conn: conn, user: user} do
    {:ok, category} = Finance.create_category(user, %{"name" => "Food", "type" => "expense"})
    {:ok, view, _html} = live(conn, ~p"/finance")
    render_click(view, "open_focus_panel", %{"panel" => "budget"})

    html = click(view, ~s(button[aria-label="Edit Food"]))
    assert html =~ "Edit category"

    view |> form("#category-form", category: %{"name" => "Food & drink"}) |> render_submit()
    assert Repo.get!(Category, category.id).name == "Food & drink"

    render_click(view, "open_focus_panel", %{"panel" => "budget"})
    click(view, ~s(button[aria-label="Delete Food & drink"]))
    click(view, ~s(button[aria-label="Confirm delete Food & drink"]))
    refute Repo.get(Category, category.id)
  end

  test "edits a debt and undoes a payment", %{conn: conn, user: user} do
    {:ok, debt} =
      Finance.create_debt(user, %{
        "name" => "Card",
        "kind" => "credit_card",
        "current_balance" => "300.00",
        "minimum_payment" => "25.00"
      })

    {:ok, _payment} =
      Finance.record_debt_payment(user, debt, %{
        "amount" => "100.00",
        "payment_date" => Date.to_iso8601(Date.utc_today())
      })

    view = open(conn, "debts")
    html = click(view, ~s(button[aria-label="Edit Card"]))
    assert html =~ "Edit debt"
    view |> form("#debt-form", debt: %{"name" => "Visa card"}) |> render_submit()
    assert Repo.get!(Debt, debt.id).name == "Visa card"
    assert Decimal.equal?(Repo.get!(Debt, debt.id).current_balance, "200.00")

    click(view, ~s(button[aria-label^="Delete "][aria-label$=" payment"]))
    click(view, ~s(button[aria-label^="Confirm delete "]))
    assert Decimal.equal?(Repo.get!(Debt, debt.id).current_balance, "300.00")
  end

  test "edits a goal and adds money to it", %{conn: conn, user: user} do
    {:ok, goal} =
      Finance.create_savings_goal(user, %{
        "name" => "Trip",
        "target_amount" => "1000",
        "saved_amount" => "0"
      })

    view = open(conn, "goals")
    html = click(view, ~s(button[aria-label="Edit Trip"]))
    assert html =~ "Edit goal"
    view |> form("#goal-form", goal: %{"target_amount" => "1200"}) |> render_submit()
    assert Decimal.equal?(Repo.get!(SavingsGoal, goal.id).target_amount, "1200")

    click(view, ~s(button[aria-label="Add money to Trip"]))

    html =
      view
      |> form("#contribute-#{goal.id}", contribution: %{"amount" => "150"})
      |> render_submit()

    assert html =~ "Added to Trip"
    assert Decimal.equal?(Repo.get!(SavingsGoal, goal.id).saved_amount, "150")
  end

  test "rejects a non-positive contribution", %{conn: conn, user: user} do
    {:ok, goal} =
      Finance.create_savings_goal(user, %{"name" => "Trip", "target_amount" => "1000"})

    view = open(conn, "goals")
    click(view, ~s(button[aria-label="Add money to Trip"]))

    html =
      view |> form("#contribute-#{goal.id}", contribution: %{"amount" => "0"}) |> render_submit()

    assert html =~ "Enter an amount above zero"
    assert Decimal.equal?(Repo.get!(SavingsGoal, goal.id).saved_amount || Decimal.new(0), "0")
  end
end

defmodule Core.FinanceTest do
  use Core.DataCase, async: true

  alias Core.Accounts
  alias Core.Finance

  test "create_budget stores the owning user and ignores user_id from attrs" do
    user = user_fixture()
    other_user = user_fixture()
    {:ok, category} = Finance.create_category(user, %{"name" => "Housing", "type" => "expense"})

    assert {:ok, budget} =
             Finance.create_budget(user, %{
               "name" => "Rent",
               "amount" => "1250.00",
               "period" => "monthly",
               "start_date" => ~D[2026-03-01],
               "alert_threshold" => 90,
               "category_id" => category.id,
               "user_id" => other_user.id
             })

    assert budget.user_id == user.id
    assert budget.alert_threshold == 90
  end

  test "get_budget_for_user!/2 scopes the query and preloads the singular category" do
    user = user_fixture()
    other_user = user_fixture()
    {:ok, category} = Finance.create_category(user, %{"name" => "Food", "type" => "expense"})

    {:ok, budget} =
      Finance.create_budget(user, %{
        "name" => "Groceries",
        "amount" => "400.00",
        "period" => "monthly",
        "start_date" => ~D[2026-03-01],
        "category_id" => category.id
      })

    loaded_budget = Finance.get_budget_for_user!(user, budget.id)

    assert loaded_budget.category.id == category.id
    assert Ecto.assoc_loaded?(loaded_budget.category)

    assert_raise Ecto.NoResultsError, fn ->
      Finance.get_budget_for_user!(other_user, budget.id)
    end
  end

  test "check_budget_status/1 uses alert_threshold for near-limit checks" do
    user = user_fixture()
    {:ok, category} = Finance.create_category(user, %{"name" => "Utilities", "type" => "expense"})

    {:ok, budget} =
      Finance.create_budget(user, %{
        "name" => "Utilities",
        "amount" => "100.00",
        "period" => "monthly",
        "start_date" => ~D[2026-03-01],
        "alert_threshold" => 70,
        "category_id" => category.id
      })

    {:ok, _transaction} =
      Finance.create_transaction(user, %{
        "amount" => "75.00",
        "type" => "expense",
        "transaction_date" => ~D[2026-03-10],
        "category_id" => category.id
      })

    status = Finance.check_budget_status(budget)

    assert status.spent == Decimal.new("75.00")
    assert status.remaining == Decimal.new("25.00")
    assert status.percentage == 75.0
    assert status.is_near_limit
    refute status.is_over
  end

  test "create_debt stores the owning user and allows missing apr" do
    user = user_fixture()
    other_user = user_fixture()

    assert {:ok, debt} =
             Finance.create_debt(user, %{
               "name" => "Rewards card",
               "kind" => "credit_card",
               "current_balance" => "1800.00",
               "minimum_payment" => "60.00",
               "user_id" => other_user.id
             })

    assert debt.user_id == user.id
    assert is_nil(debt.apr)
  end

  test "generate_debt_payoff_comparison returns snowball and avalanche plans" do
    user = user_fixture()

    {:ok, _small_high_apr} =
      Finance.create_debt(user, %{
        "name" => "Card",
        "kind" => "credit_card",
        "current_balance" => "500.00",
        "apr" => "25.0",
        "minimum_payment" => "25.00"
      })

    {:ok, _large_low_apr} =
      Finance.create_debt(user, %{
        "name" => "Loan",
        "kind" => "loan",
        "current_balance" => "2500.00",
        "apr" => "7.5",
        "minimum_payment" => "100.00"
      })

    plans =
      Finance.generate_debt_payoff_comparison(user,
        today: ~D[2026-04-15],
        starts_on: ~D[2026-05-01],
        monthly_amount: Decimal.new("600.00")
      )

    snowball = Enum.find(plans, &(&1.strategy == "snowball"))
    avalanche = Enum.find(plans, &(&1.strategy == "avalanche"))

    assert snowball.feasible?
    assert avalanche.feasible?
    assert List.first(snowball.payoff_order).name == "Card"
    assert List.first(avalanche.payoff_order).name == "Card"
    assert snowball.payoff_months > 0
  end

  test "financial health uses current month income and excludes linked debt payment expenses" do
    user = user_fixture()
    {:ok, category} = Finance.create_category(user, %{"name" => "Debt", "type" => "expense"})

    {:ok, debt} =
      Finance.create_debt(user, %{
        "name" => "Card",
        "kind" => "credit_card",
        "current_balance" => "1000.00",
        "minimum_payment" => "50.00"
      })

    {:ok, _income} =
      Finance.create_transaction(user, %{
        "amount" => "3000.00",
        "type" => "income",
        "transaction_date" => ~D[2026-04-05]
      })

    {:ok, _regular_expense} =
      Finance.create_transaction(user, %{
        "amount" => "500.00",
        "type" => "expense",
        "transaction_date" => ~D[2026-04-06]
      })

    {:ok, debt_transaction} =
      Finance.create_transaction(user, %{
        "amount" => "75.00",
        "type" => "expense",
        "transaction_date" => ~D[2026-04-07],
        "category_id" => category.id
      })

    {:ok, _payment} =
      Finance.record_debt_payment(user, debt, %{
        "amount" => "75.00",
        "payment_date" => ~D[2026-04-07],
        "transaction_id" => debt_transaction.id
      })

    health = Finance.get_financial_health(user, today: ~D[2026-04-15])

    assert health.current_month.income == Decimal.new("3000.00")
    assert health.current_month.expenses == Decimal.new("500.00")
    assert health.current_month.free_cash_flow == Decimal.new("2500.00")
    assert health.minimum_debt_payment == Decimal.new("50.00")

    assert "One or more debts are missing APR, so projections may be understated." in health.warnings
  end

  test "record_debt_payment reduces balance and creates a linked expense transaction" do
    user = user_fixture()

    {:ok, debt} =
      Finance.create_debt(user, %{
        "name" => "Card",
        "kind" => "credit_card",
        "current_balance" => "1000.00",
        "minimum_payment" => "50.00"
      })

    assert {:ok, payment} =
             Finance.record_debt_payment(user, debt, %{
               "amount" => "125.00",
               "payment_date" => ~D[2026-04-12],
               "kind" => "extra",
               "notes" => "Bonus payment",
               "create_expense_transaction" => "true"
             })

    updated_debt = Finance.get_debt_for_user!(user, debt.id)

    assert updated_debt.current_balance == Decimal.new("875.00")
    assert payment.transaction_id

    transaction = Finance.get_transaction_for_user!(user, payment.transaction_id)
    assert transaction.amount == Decimal.new("125.00")
    assert transaction.type == "expense"
    assert transaction.description == "Debt payment: Card"
    assert transaction.transaction_date == ~D[2026-04-12]
  end

  test "record_debt_payment marks debt paid off when balance reaches zero" do
    user = user_fixture()

    {:ok, debt} =
      Finance.create_debt(user, %{
        "name" => "Small loan",
        "kind" => "loan",
        "current_balance" => "100.00",
        "minimum_payment" => "25.00"
      })

    assert {:ok, _payment} =
             Finance.record_debt_payment(user, debt, %{
               "amount" => "100.00",
               "payment_date" => ~D[2026-04-12],
               "kind" => "extra"
             })

    updated_debt = Finance.get_debt_for_user!(user, debt.id)

    assert updated_debt.current_balance == Decimal.new("0.00")
    assert updated_debt.status == "paid_off"
  end

  test "record_debt_payment rejects overpayments for regular payment kinds" do
    user = user_fixture()

    {:ok, debt} =
      Finance.create_debt(user, %{
        "name" => "Card",
        "kind" => "credit_card",
        "current_balance" => "100.00",
        "minimum_payment" => "25.00"
      })

    assert {:error, changeset} =
             Finance.record_debt_payment(user, debt, %{
               "amount" => "125.00",
               "payment_date" => ~D[2026-04-12],
               "kind" => "extra"
             })

    assert "cannot exceed current balance" in errors_on(changeset).amount
  end

  test "record_debt_payment blocks payments against another user's debt" do
    user = user_fixture()
    other_user = user_fixture()

    {:ok, debt} =
      Finance.create_debt(other_user, %{
        "name" => "Other card",
        "kind" => "credit_card",
        "current_balance" => "100.00",
        "minimum_payment" => "25.00"
      })

    assert {:error, :forbidden} =
             Finance.record_debt_payment(user, debt, %{
               "amount" => "25.00",
               "payment_date" => ~D[2026-04-12],
               "kind" => "minimum"
             })
  end

  defp user_fixture do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        email: "finance_user_#{unique}@example.com",
        password: "Password123!",
        username: "finance_user_#{unique}",
        full_name: "Finance User"
      })

    user
  end
end

defmodule Core.FinanceTest do
  use Core.DataCase, async: true

  alias Core.Accounts
  alias Core.Accounts.Household
  alias Core.Finance

  test "create_account stores the owning scope and is listed by that scope" do
    user = user_fixture()
    {:ok, %Household{} = household} = Accounts.create_household(user, %{"name" => "Shared Home"})

    assert {:ok, personal_account} =
             Finance.create_account(user, %{
               "name" => "Main checking",
               "kind" => "checking",
               "current_balance" => "2500.00"
             })

    assert {:ok, household_account} =
             Finance.create_account(user, household, %{
               "name" => "Household reserve",
               "kind" => "savings",
               "current_balance" => "800.00"
             })

    assert personal_account.user_id == user.id
    assert is_nil(personal_account.household_id)
    assert household_account.household_id == household.id
    assert is_nil(household_account.user_id)

    {:ok, personal_accounts} = Finance.list_accounts(user, user)
    {:ok, household_accounts} = Finance.list_accounts(user, household)

    assert Enum.any?(personal_accounts, &(&1.id == personal_account.id))
    refute Enum.any?(personal_accounts, &(&1.id == household_account.id))
    assert Enum.any?(household_accounts, &(&1.id == household_account.id))
  end

  test "list_transactions supports sort, offset, account filter, and count_transactions" do
    user = user_fixture()

    {:ok, account} =
      Finance.create_account(user, %{
        "name" => "Sorted checking",
        "kind" => "checking",
        "current_balance" => "1000.00"
      })

    for {amount, date} <- [
          {"10.00", ~D[2026-05-01]},
          {"30.00", ~D[2026-05-03]},
          {"20.00", ~D[2026-05-02]}
        ] do
      {:ok, _} =
        Finance.create_transaction(user, user, %{
          "amount" => amount,
          "type" => "expense",
          "description" => "txn #{amount}",
          "transaction_date" => Date.to_iso8601(date),
          "account_id" => account.id
        })
    end

    {:ok, by_amount_asc} = Finance.list_transactions(user, user, sort: {:amount, :asc})
    assert Enum.map(by_amount_asc, &Decimal.to_string(&1.amount)) == ["10.00", "20.00", "30.00"]

    {:ok, by_date_desc} = Finance.list_transactions(user, user, sort: {:transaction_date, :desc})

    assert Enum.map(by_date_desc, & &1.transaction_date) ==
             [~D[2026-05-03], ~D[2026-05-02], ~D[2026-05-01]]

    {:ok, page_two} =
      Finance.list_transactions(user, user, sort: {:amount, :asc}, limit: 2, offset: 2)

    assert Enum.map(page_two, &Decimal.to_string(&1.amount)) == ["30.00"]

    {:ok, filtered} = Finance.list_transactions(user, user, account_id: account.id)
    assert length(filtered) == 3

    assert {:ok, 3} = Finance.count_transactions(user, user)
    assert {:ok, 3} = Finance.count_transactions(user, user, limit: 1, offset: 5)

    # an unrelated sort option value falls back to the default order safely
    {:ok, _} = Finance.list_transactions(user, user, sort: {:description, :asc})
  end

  describe "create_account_transfer/3" do
    setup do
      user = user_fixture()

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

      %{user: user, from_account: from_account, to_account: to_account}
    end

    test "creates linked legs and moves both balances", ctx do
      assert {:ok, {out_leg, in_leg}} =
               Finance.create_account_transfer(ctx.user, ctx.user, %{
                 "from_account_id" => ctx.from_account.id,
                 "to_account_id" => ctx.to_account.id,
                 "amount" => "150.00"
               })

      assert out_leg.type == "expense"
      assert in_leg.type == "income"
      assert out_leg.counterpart_transaction_id == in_leg.id
      assert in_leg.counterpart_transaction_id == out_leg.id
      assert out_leg.description == "Transfer to Savings"
      assert in_leg.description == "Transfer from Checking"

      from_account = Finance.get_account!(ctx.user, ctx.user, ctx.from_account.id)
      to_account = Finance.get_account!(ctx.user, ctx.user, ctx.to_account.id)
      assert Decimal.equal?(from_account.current_balance, Decimal.new("850.00"))
      assert Decimal.equal?(to_account.current_balance, Decimal.new("350.00"))
    end

    test "transfer legs are excluded from income/expense aggregates", ctx do
      today = Date.utc_today()

      {:ok, _} =
        Finance.create_transaction(ctx.user, ctx.user, %{
          "amount" => "500.00",
          "type" => "income",
          "description" => "Salary",
          "transaction_date" => Date.to_iso8601(today)
        })

      {:ok, _legs} =
        Finance.create_account_transfer(ctx.user, ctx.user, %{
          "from_account_id" => ctx.from_account.id,
          "to_account_id" => ctx.to_account.id,
          "amount" => "150.00"
        })

      start_date = Date.beginning_of_month(today)
      end_date = Date.end_of_month(today)

      assert Decimal.equal?(
               Finance.calculate_total_income(ctx.user, start_date, end_date),
               Decimal.new("500.00")
             )

      assert Decimal.equal?(
               Finance.calculate_total_expenses(ctx.user, start_date, end_date),
               Decimal.new("0")
             )

      summary = Finance.get_currency_summary(ctx.user, start_date, end_date)
      assert [%{amount: income}] = summary.income
      assert Decimal.equal?(income, Decimal.new("500.00"))
      assert summary.expenses == []

      # both legs still appear in the ledger listing
      {:ok, listed} = Finance.list_transactions(ctx.user, ctx.user)
      assert Enum.count(listed, & &1.counterpart_transaction_id) == 2
    end

    test "deleting one leg removes both and reverses balances", ctx do
      {:ok, {out_leg, _in_leg}} =
        Finance.create_account_transfer(ctx.user, ctx.user, %{
          "from_account_id" => ctx.from_account.id,
          "to_account_id" => ctx.to_account.id,
          "amount" => "150.00"
        })

      assert {:ok, _} = Finance.delete_transaction(ctx.user, out_leg)

      {:ok, listed} = Finance.list_transactions(ctx.user, ctx.user)
      assert listed == []

      from_account = Finance.get_account!(ctx.user, ctx.user, ctx.from_account.id)
      to_account = Finance.get_account!(ctx.user, ctx.user, ctx.to_account.id)
      assert Decimal.equal?(from_account.current_balance, Decimal.new("1000.00"))
      assert Decimal.equal?(to_account.current_balance, Decimal.new("200.00"))
    end

    test "rejects same account, cross-currency, bad amounts, and foreign scopes", ctx do
      assert {:error, :same_account} =
               Finance.create_account_transfer(ctx.user, ctx.user, %{
                 "from_account_id" => ctx.from_account.id,
                 "to_account_id" => ctx.from_account.id,
                 "amount" => "10.00"
               })

      {:ok, usd_account} =
        Finance.create_account(ctx.user, %{
          "name" => "USD account",
          "kind" => "checking",
          "currency" => "USD",
          "current_balance" => "100.00"
        })

      assert {:error, :currency_mismatch} =
               Finance.create_account_transfer(ctx.user, ctx.user, %{
                 "from_account_id" => ctx.from_account.id,
                 "to_account_id" => usd_account.id,
                 "amount" => "10.00"
               })

      assert {:error, :invalid_transfer_amount} =
               Finance.create_account_transfer(ctx.user, ctx.user, %{
                 "from_account_id" => ctx.from_account.id,
                 "to_account_id" => ctx.to_account.id,
                 "amount" => "-5.00"
               })

      other_user = user_fixture()

      {:ok, foreign_account} =
        Finance.create_account(other_user, %{
          "name" => "Foreign",
          "kind" => "checking",
          "currency" => "DOP",
          "current_balance" => "50.00"
        })

      assert {:error, :invalid_account_scope} =
               Finance.create_account_transfer(ctx.user, ctx.user, %{
                 "from_account_id" => ctx.from_account.id,
                 "to_account_id" => foreign_account.id,
                 "amount" => "10.00"
               })
    end
  end

  test "create_transaction rejects accounts from another scope" do
    user = user_fixture()
    {:ok, %Household{} = household} = Accounts.create_household(user, %{"name" => "Scope Home"})

    {:ok, account} =
      Finance.create_account(user, %{
        "name" => "Personal checking",
        "kind" => "checking",
        "current_balance" => "1200.00"
      })

    assert {:error, :invalid_account_scope} =
             Finance.create_transaction(user, household, %{
               "amount" => "20.00",
               "type" => "expense",
               "transaction_date" => ~D[2026-04-10],
               "account_id" => account.id
             })
  end

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

  test "pending review transactions are excluded from budget status and health" do
    user = user_fixture()
    {:ok, category} = Finance.create_category(user, %{"name" => "Food", "type" => "expense"})

    {:ok, budget} =
      Finance.create_budget(user, %{
        "name" => "Food",
        "amount" => "200.00",
        "period" => "monthly",
        "start_date" => ~D[2026-04-01],
        "category_id" => category.id
      })

    {:ok, _pending_transaction} =
      Finance.create_transaction(user, %{
        "amount" => "80.00",
        "type" => "expense",
        "transaction_date" => ~D[2026-04-10],
        "category_id" => category.id,
        "status" => "pending_review",
        "source" => "email"
      })

    status = Finance.check_budget_status(budget)
    health = Finance.get_financial_health(user, today: ~D[2026-04-15])

    assert status.spent == Decimal.new("0")
    assert status.remaining == Decimal.new("200.00")
    assert health.current_month.expenses == Decimal.new("0")
  end

  test "list_pending_transactions_for_user/2 returns pending items only" do
    user = user_fixture()

    {:ok, pending_transaction} =
      Finance.create_transaction(user, %{
        "amount" => "80.00",
        "type" => "expense",
        "transaction_date" => ~D[2026-04-10],
        "status" => "pending_review",
        "source" => "email"
      })

    {:ok, _confirmed_transaction} =
      Finance.create_transaction(user, %{
        "amount" => "1200.00",
        "type" => "income",
        "transaction_date" => ~D[2026-04-11]
      })

    assert [transaction] = Finance.list_pending_transactions_for_user(user)
    assert transaction.id == pending_transaction.id
  end

  test "confirm_transaction updates and confirms a pending transaction" do
    user = user_fixture()

    {:ok, transaction} =
      Finance.create_transaction(user, %{
        "amount" => "80.00",
        "type" => "expense",
        "transaction_date" => ~D[2026-04-10],
        "status" => "pending_review",
        "source" => "email",
        "review_reason" => "Matched bank alert"
      })

    assert {:ok, confirmed} =
             Finance.confirm_transaction(user, transaction, %{
               "description" => "Coffee shop",
               "merchant" => "Cafe",
               "payment_method" => "card"
             })

    assert confirmed.status == "confirmed"
    assert confirmed.description == "Coffee shop"
    assert confirmed.merchant == "Cafe"
    assert is_nil(confirmed.review_reason)
  end

  test "ignore_transaction marks a pending transaction as ignored" do
    user = user_fixture()

    {:ok, transaction} =
      Finance.create_transaction(user, %{
        "amount" => "80.00",
        "type" => "expense",
        "transaction_date" => ~D[2026-04-10],
        "status" => "pending_review",
        "source" => "email"
      })

    assert {:ok, ignored} = Finance.ignore_transaction(user, transaction)
    assert ignored.status == "ignored"
    assert Finance.list_pending_transactions_for_user(user) == []
  end

  test "transaction external_id is unique per user" do
    user = user_fixture()

    assert {:ok, _transaction} =
             Finance.create_transaction(user, %{
               "amount" => "80.00",
               "type" => "expense",
               "transaction_date" => ~D[2026-04-10],
               "status" => "pending_review",
               "source" => "email",
               "external_id" => "email-123"
             })

    assert {:error, changeset} =
             Finance.create_transaction(user, %{
               "amount" => "120.00",
               "type" => "expense",
               "transaction_date" => ~D[2026-04-10],
               "status" => "pending_review",
               "source" => "email",
               "external_id" => "email-123"
             })

    assert "has already been taken" in errors_on(changeset).external_id
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

  test "get_financial_health/3 rejects access to another user's household" do
    user = user_fixture()
    other_user = user_fixture()

    {:ok, %Household{} = household} =
      Accounts.create_household(other_user, %{"name" => "Private Home"})

    assert {:error, :forbidden} =
             Finance.get_financial_health(user, household, today: ~D[2026-04-15])
  end

  test "list_debt_payments_for_debt/2 returns household-scoped payments" do
    user = user_fixture()
    {:ok, %Household{} = household} = Accounts.create_household(user, %{"name" => "Shared Home"})

    {:ok, debt} =
      Finance.create_debt(user, household, %{
        "name" => "Shared card",
        "kind" => "credit_card",
        "current_balance" => "600.00",
        "minimum_payment" => "50.00"
      })

    assert {:ok, payment} =
             Finance.record_debt_payment(user, debt, %{
               "amount" => "120.00",
               "payment_date" => ~D[2026-04-12],
               "kind" => "extra",
               "create_expense_transaction" => "true"
             })

    assert [listed_payment] = Finance.list_debt_payments_for_debt(user, debt)
    assert listed_payment.id == payment.id
    assert listed_payment.household_id == household.id
  end

  test "list_account_summaries returns balances and period totals by scoped account" do
    user = user_fixture()

    {:ok, account} =
      Finance.create_account(user, %{
        "name" => "Main checking",
        "kind" => "checking",
        "current_balance" => "2400.00"
      })

    {:ok, _income} =
      Finance.create_transaction(user, %{
        "amount" => "500.00",
        "type" => "income",
        "transaction_date" => ~D[2026-04-05],
        "account_id" => account.id
      })

    {:ok, _expense} =
      Finance.create_transaction(user, %{
        "amount" => "125.00",
        "type" => "expense",
        "transaction_date" => ~D[2026-04-06],
        "account_id" => account.id
      })

    assert {:ok, [summary]} =
             Finance.list_account_summaries(user, user, ~D[2026-04-01], ~D[2026-04-30])

    assert summary.account.id == account.id
    assert summary.income == Decimal.new("500.00")
    assert summary.expenses == Decimal.new("125.00")
    assert summary.net == Decimal.new("375.00")
    assert summary.transaction_count == 2
  end

  test "household finance records stay isolated from personal records" do
    user = user_fixture()
    {:ok, %Household{} = household} = Accounts.create_household(user, %{"name" => "Shared Home"})

    {:ok, personal_category} =
      Finance.create_category(user, %{"name" => "Personal Food", "type" => "expense"})

    {:ok, household_category} =
      Finance.create_category(user, household, %{"name" => "Shared Food", "type" => "expense"})

    {:ok, _personal_transaction} =
      Finance.create_transaction(user, %{
        "amount" => "25.00",
        "type" => "expense",
        "transaction_date" => ~D[2026-04-10],
        "description" => "Personal lunch",
        "category_id" => personal_category.id
      })

    assert {:ok, _household_transaction} =
             Finance.create_transaction(user, household, %{
               "amount" => "90.00",
               "type" => "expense",
               "transaction_date" => ~D[2026-04-10],
               "description" => "Shared groceries",
               "category_id" => household_category.id
             })

    {:ok, personal_transactions} = Finance.list_transactions(user, user)
    {:ok, household_transactions} = Finance.list_transactions(user, household)

    assert Enum.any?(personal_transactions, &(&1.description == "Personal lunch"))
    refute Enum.any?(personal_transactions, &(&1.description == "Shared groceries"))
    assert Enum.any?(household_transactions, &(&1.description == "Shared groceries"))
    refute Enum.any?(household_transactions, &(&1.description == "Personal lunch"))
  end

  test "household finance rejects categories from another scope" do
    user = user_fixture()
    {:ok, %Household{} = household} = Accounts.create_household(user, %{"name" => "Scope Home"})

    {:ok, personal_category} =
      Finance.create_category(user, %{"name" => "Personal", "type" => "expense"})

    assert {:error, :invalid_category_scope} =
             Finance.create_transaction(user, household, %{
               "amount" => "20.00",
               "type" => "expense",
               "transaction_date" => ~D[2026-04-10],
               "category_id" => personal_category.id
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

defmodule Core.Finance.BalanceEngineTest do
  @moduledoc """
  Account balances follow every money write: transactions, transfers,
  adjustments, debt payments and goal contributions.
  """
  use Core.DataCase, async: true

  alias Core.Finance
  alias Core.Finance.{Account, Debt, SavingsGoal, Transaction}

  setup do
    user = user_fixture()
    checking = account!(user, "Checking", "checking", "10000")
    %{user: user, checking: checking}
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

  defp txn!(user, account, type, amount, extra \\ %{}) do
    {:ok, transaction} =
      Finance.create_transaction(
        user,
        Map.merge(
          %{
            "type" => type,
            "amount" => amount,
            "transaction_date" => Date.utc_today(),
            "description" => "#{type} #{amount}",
            "account_id" => account.id
          },
          extra
        )
      )

    transaction
  end

  defp balance(account), do: Repo.get!(Account, account.id).current_balance

  defp assert_balance(account, expected) do
    actual = balance(account)

    assert Decimal.equal?(actual, Decimal.new(expected)),
           "expected #{account.name} to hold #{expected}, got #{actual}"
  end

  describe "transactions move their account's balance" do
    test "create, edit and delete", %{user: user, checking: checking} do
      expense = txn!(user, checking, "expense", "250")
      assert_balance(checking, "9750")

      txn!(user, checking, "income", "1000")
      assert_balance(checking, "10750")

      {:ok, expense} = Finance.update_transaction(user, expense, %{"amount" => "300"})
      assert_balance(checking, "10700")

      {:ok, expense} = Finance.update_transaction(user, expense, %{"type" => "income"})
      assert_balance(checking, "11300")

      {:ok, _} = Finance.delete_transaction(user, expense)
      assert_balance(checking, "11000")
    end

    test "moving a transaction to another account moves the money", %{
      user: user,
      checking: checking
    } do
      cash = account!(user, "Cash", "cash", "500")
      expense = txn!(user, checking, "expense", "100")

      {:ok, _} = Finance.update_transaction(user, expense, %{"account_id" => cash.id})

      assert_balance(checking, "10000")
      assert_balance(cash, "400")
    end

    test "pending rows count only once confirmed", %{user: user, checking: checking} do
      pending = txn!(user, checking, "expense", "80", %{"status" => "pending_review"})
      assert_balance(checking, "10000")

      {:ok, confirmed} = Finance.confirm_transaction(user, pending)
      assert_balance(checking, "9920")

      {:ok, _} = Finance.ignore_transaction(user, confirmed)
      assert_balance(checking, "10000")
    end

    test "a stale account struct can't overwrite newer balances", %{
      user: user,
      checking: checking
    } do
      stale = checking
      txn!(user, checking, "expense", "100")
      txn!(user, stale, "expense", "100")
      assert_balance(checking, "9800")
    end

    test "archived accounts take no new transactions", %{user: user, checking: checking} do
      old = account!(user, "Old", "checking", "0")
      {:ok, _} = Finance.archive_account(user, old)

      assert {:error, :archived_account} =
               Finance.create_transaction(user, %{
                 "type" => "expense",
                 "amount" => "5",
                 "transaction_date" => Date.utc_today(),
                 "account_id" => old.id
               })

      # a row already on a since-archived account can still be edited
      expense = txn!(user, checking, "expense", "5")
      {:ok, _} = Finance.archive_account(user, checking)
      assert {:ok, _} = Finance.update_transaction(user, expense, %{"description" => "Lunch"})
    end

    test "update_account no longer overwrites the balance", %{user: user, checking: checking} do
      {:ok, _} =
        Finance.update_account(user, checking, %{"name" => "Main", "current_balance" => "1"})

      assert_balance(checking, "10000")
      assert Repo.get!(Account, checking.id).name == "Main"
    end
  end

  describe "adjust_account_balance/4" do
    test "records the difference as an adjustment outside income and spending", %{
      user: user,
      checking: checking
    } do
      {:ok, adjustment} = Finance.adjust_account_balance(user, checking, "9500.50")

      assert adjustment.balance_adjustment
      assert adjustment.type == "expense"
      assert Decimal.equal?(adjustment.amount, "499.50")
      assert_balance(checking, "9500.50")

      today = Date.utc_today()
      summary = Finance.get_currency_summary(user, today, today)
      assert summary.expenses == []
      assert summary.income == []

      assert {:ok, :unchanged} = Finance.adjust_account_balance(user, checking, "9500.5")
      assert {:error, :invalid_balance} = Finance.adjust_account_balance(user, checking, "lots")
    end

    test "deleting an adjustment undoes it", %{user: user, checking: checking} do
      {:ok, adjustment} = Finance.adjust_account_balance(user, checking, "12000")
      assert adjustment.type == "income"
      {:ok, _} = Finance.delete_transaction(user, adjustment)
      assert_balance(checking, "10000")
    end
  end

  describe "transfers" do
    test "paying a credit card brings what's owed toward zero", %{
      user: user,
      checking: checking
    } do
      card = account!(user, "Visa", "credit_card", "-5000")

      {:ok, _} =
        Finance.create_account_transfer(user, user, %{
          "from_account_id" => checking.id,
          "to_account_id" => card.id,
          "amount" => "2000"
        })

      assert_balance(checking, "8000")
      assert_balance(card, "-3000")

      # spending on the card makes it owe more
      txn!(user, card, "expense", "150")
      assert_balance(card, "-3150")
    end

    test "different currencies need the amount received", %{user: user, checking: checking} do
      usd = account!(user, "Dollars", "savings", "0", "USD")
      attrs = %{"from_account_id" => checking.id, "to_account_id" => usd.id, "amount" => "5910"}

      assert {:error, :currency_mismatch} = Finance.create_account_transfer(user, user, attrs)

      {:ok, {out_leg, in_leg}} =
        Finance.create_account_transfer(user, user, Map.put(attrs, "received_amount", "100"))

      assert_balance(checking, "4090")
      assert_balance(usd, "100")
      assert Decimal.equal?(out_leg.amount, "5910")
      assert Decimal.equal?(in_leg.amount, "100")
      assert out_leg.description =~ "1 USD = 59.10 DOP"
    end

    test "editing a transfer moves both legs and both balances", %{
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

      assert {:error, :transfer_leg} =
               Finance.update_transaction(user, out_leg, %{"amount" => "5"})

      {:ok, {out_leg, in_leg}} =
        Finance.update_account_transfer(user, out_leg, %{
          "amount" => "1500",
          "transaction_date" => "2026-01-15",
          "notes" => "Rent fund"
        })

      assert_balance(checking, "8500")
      assert_balance(savings, "1500")
      assert Decimal.equal?(in_leg.amount, "1500")
      assert in_leg.transaction_date == ~D[2026-01-15]
      assert out_leg.notes == "Rent fund"

      {:ok, _} = Finance.delete_transaction(user, in_leg)
      assert_balance(checking, "10000")
      assert_balance(savings, "0")
    end

    test "transfers don't count in health or budgets", %{user: user, checking: checking} do
      savings = account!(user, "Savings", "savings", "0")
      today = Date.utc_today()

      {:ok, budget} =
        Finance.create_budget(user, %{
          "name" => "Everything",
          "amount" => "1000",
          "currency" => "DOP",
          "period" => "monthly",
          "start_date" => Date.beginning_of_month(today)
        })

      {:ok, _} =
        Finance.create_account_transfer(user, user, %{
          "from_account_id" => checking.id,
          "to_account_id" => savings.id,
          "amount" => "700",
          "transaction_date" => today
        })

      assert Decimal.equal?(Finance.check_budget_status(budget).spent, 0)

      health = Finance.get_financial_health(user, today: today)
      assert Decimal.equal?(health.current_month.expenses, 0)
      assert Decimal.equal?(health.current_month.income, 0)
    end
  end

  describe "debt payments from an account" do
    setup %{user: user} do
      {:ok, debt} =
        Finance.create_debt(user, %{
          "name" => "Car loan",
          "kind" => "loan",
          "currency" => "DOP",
          "current_balance" => "3000",
          "minimum_payment" => "500"
        })

      %{debt: debt}
    end

    test "the money leaves the account, and undoing restores both", %{
      user: user,
      checking: checking,
      debt: debt
    } do
      {:ok, payment} =
        Finance.record_debt_payment(user, debt, %{
          "amount" => "500",
          "payment_date" => Date.utc_today(),
          "kind" => "minimum",
          "account_id" => checking.id
        })

      assert_balance(checking, "9500")
      assert Decimal.equal?(Repo.get!(Debt, debt.id).current_balance, "2500")

      {:ok, _} = Finance.delete_debt_payment(user, payment)
      assert_balance(checking, "10000")
      assert Decimal.equal?(Repo.get!(Debt, debt.id).current_balance, "3000")
    end

    test "deleting the payment's expense undoes the payment", %{
      user: user,
      checking: checking,
      debt: debt
    } do
      {:ok, payment} =
        Finance.record_debt_payment(user, debt, %{
          "amount" => "800",
          "payment_date" => Date.utc_today(),
          "kind" => "extra",
          "account_id" => checking.id
        })

      expense = Repo.get!(Transaction, payment.transaction_id)
      {:ok, _} = Finance.delete_transaction(user, expense)

      assert_balance(checking, "10000")
      assert Decimal.equal?(Repo.get!(Debt, debt.id).current_balance, "3000")
    end

    test "no kind of payment can exceed the balance", %{user: user, debt: debt} do
      assert {:error, changeset} =
               Finance.record_debt_payment(user, debt, %{
                 "amount" => "3500",
                 "payment_date" => Date.utc_today(),
                 "kind" => "settlement"
               })

      assert %{amount: ["cannot exceed current balance"]} = errors_on(changeset)
    end

    test "the account must match the debt's currency", %{user: user, debt: debt} do
      usd = account!(user, "Dollars", "checking", "100", "USD")

      assert {:error, :currency_mismatch} =
               Finance.record_debt_payment(user, debt, %{
                 "amount" => "50",
                 "payment_date" => Date.utc_today(),
                 "kind" => "extra",
                 "account_id" => usd.id
               })
    end
  end

  describe "goal contributions from an account" do
    test "transfer into the goal's account and raise what's saved", %{
      user: user,
      checking: checking
    } do
      vault = account!(user, "Vault", "savings", "0")

      {:ok, goal} =
        Finance.create_savings_goal(user, %{
          "name" => "Trip",
          "target_amount" => "2000",
          "currency" => "DOP",
          "account_id" => vault.id
        })

      {:ok, goal} =
        Finance.contribute_to_savings_goal(user, goal, Decimal.new("750"),
          from_account_id: checking.id
        )

      assert Decimal.equal?(goal.saved_amount, "750")
      assert_balance(checking, "9250")
      assert_balance(vault, "750")
    end

    test "money can only move into a goal with a linked account", %{
      user: user,
      checking: checking
    } do
      {:ok, goal} =
        Finance.create_savings_goal(user, %{
          "name" => "Trip",
          "target_amount" => "2000",
          "currency" => "DOP"
        })

      assert {:error, :goal_has_no_account} =
               Finance.contribute_to_savings_goal(user, goal, Decimal.new("10"),
                 from_account_id: checking.id
               )

      assert Decimal.equal?(Repo.get!(SavingsGoal, goal.id).saved_amount, 0)
    end

    test "a linked account must share the goal's currency", %{user: user} do
      usd = account!(user, "Dollars", "savings", "0", "USD")

      assert {:error, :currency_mismatch} =
               Finance.create_savings_goal(user, %{
                 "name" => "Trip",
                 "target_amount" => "2000",
                 "currency" => "DOP",
                 "account_id" => usd.id
               })
    end
  end
end

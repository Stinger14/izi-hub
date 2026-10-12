defmodule Core.Finance.EditableRecordsTest do
  use Core.DataCase, async: true

  alias Core.{Accounts, Finance}
  alias Core.Finance.{Account, Debt, Transaction}

  defp account(user, attrs \\ %{}) do
    {:ok, account} =
      Finance.create_account(
        user,
        Map.merge(
          %{"name" => "Checking", "kind" => "checking", "current_balance" => "100.00"},
          attrs
        )
      )

    account
  end

  describe "accounts" do
    test "edits details but never the owner or status" do
      user = user_fixture()
      other = user_fixture()
      acct = account(user)

      assert {:ok, updated} =
               Finance.update_account(user, acct, %{
                 "name" => "Main checking",
                 "institution" => "Popular",
                 "status" => "archived",
                 "user_id" => other.id
               })

      assert updated.name == "Main checking"
      assert updated.institution == "Popular"
      assert updated.status == "active"
      assert updated.user_id == user.id
    end

    test "locks the currency once the account has transactions" do
      user = user_fixture()
      acct = account(user)

      assert {:ok, %{currency: "USD"}} =
               Finance.update_account(user, acct, %{"currency" => "USD"})

      acct = account(user, %{"name" => "Used"})

      {:ok, _} =
        Finance.create_transaction(user, %{
          "amount" => "5",
          "type" => "expense",
          "transaction_date" => Date.to_iso8601(Date.utc_today()),
          "account_id" => acct.id
        })

      assert {:error, changeset} = Finance.update_account(user, acct, %{"currency" => "USD"})
      assert "can't change once the account has transactions" in errors_on(changeset).currency
    end

    test "archives and restores, hiding it from active lists" do
      user = user_fixture()
      acct = account(user)

      assert {:ok, %{status: "archived"}} = Finance.archive_account(user, acct)
      assert {:ok, []} = Finance.list_accounts(user, user)
      assert {:ok, [%{id: id}]} = Finance.list_archived_accounts(user, user)
      assert id == acct.id

      assert {:ok, %{status: "active"}} =
               Finance.restore_account(user, Repo.get!(Account, acct.id))

      assert {:ok, [_]} = Finance.list_accounts(user, user)
    end

    test "deletes only accounts without transactions" do
      user = user_fixture()
      empty = account(user, %{"name" => "Mistake"})
      assert {:ok, _} = Finance.delete_account(user, empty)
      refute Repo.get(Account, empty.id)

      used = account(user, %{"name" => "Used"})

      {:ok, _} =
        Finance.create_transaction(user, %{
          "amount" => "5",
          "type" => "expense",
          "transaction_date" => Date.to_iso8601(Date.utc_today()),
          "account_id" => used.id
        })

      assert {:error, :has_transactions} = Finance.delete_account(user, used)
      assert Repo.get(Account, used.id)
    end

    test "household members can edit shared accounts; outsiders can't" do
      owner = user_fixture()
      member = user_fixture()
      outsider = user_fixture()
      {:ok, household} = Accounts.create_household(owner, %{"name" => "Home"})
      {:ok, _} = Accounts.add_household_member(owner, household, member)

      {:ok, shared} =
        Finance.create_account(owner, household, %{
          "name" => "Shared",
          "kind" => "checking",
          "current_balance" => "1"
        })

      assert {:ok, _} = Finance.update_account(member, shared, %{"name" => "Shared pot"})
      assert {:error, :forbidden} = Finance.update_account(outsider, shared, %{"name" => "Mine"})
      assert {:error, :forbidden} = Finance.archive_account(outsider, shared)
      assert {:error, :forbidden} = Finance.delete_account(outsider, shared)
    end
  end

  describe "debt payments" do
    test "deleting a payment restores the balance, reopens the debt and removes its expense" do
      user = user_fixture()

      {:ok, debt} =
        Finance.create_debt(user, %{
          "name" => "Card",
          "kind" => "credit_card",
          "current_balance" => "50.00",
          "minimum_payment" => "10.00"
        })

      {:ok, payment} =
        Finance.record_debt_payment(user, debt, %{
          "amount" => "50.00",
          "payment_date" => Date.to_iso8601(Date.utc_today()),
          "create_expense_transaction" => "true"
        })

      paid = Repo.get!(Debt, debt.id)
      assert paid.status == "paid_off"
      assert payment.transaction_id

      assert {:ok, _} = Finance.delete_debt_payment(user, payment)

      restored = Repo.get!(Debt, debt.id)
      assert Decimal.equal?(restored.current_balance, "50.00")
      assert restored.status == "active"
      refute Repo.get(Transaction, payment.transaction_id)
    end
  end
end

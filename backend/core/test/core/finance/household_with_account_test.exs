defmodule Core.Finance.HouseholdWithAccountTest do
  use Core.DataCase, async: true

  alias Core.{Accounts, Finance}

  test "creates the household and its starting account" do
    user = user_fixture()

    assert {:ok, household} =
             Finance.create_household_with_account(user, %{"name" => "Garcia Home"}, %{
               "name" => "",
               "current_balance" => "1500.50",
               "kind" => "savings",
               "currency" => "USD"
             })

    assert {:ok, [account]} = Finance.list_accounts(user, household)
    assert account.name == "Household account"
    assert account.kind == "savings"
    assert account.currency == "USD"
    assert Decimal.equal?(account.current_balance, Decimal.new("1500.50"))
    assert {:ok, []} = Finance.list_accounts(user, user)
  end

  test "blank starting-account fields create only the household" do
    user = user_fixture()

    assert {:ok, household} =
             Finance.create_household_with_account(user, %{"name" => "Garcia Home"}, %{
               "name" => " ",
               "current_balance" => "",
               "kind" => "checking",
               "currency" => "DOP"
             })

    assert {:ok, []} = Finance.list_accounts(user, household)
  end

  test "an invalid account rolls the household back" do
    user = user_fixture()

    assert {:error, :account, changeset} =
             Finance.create_household_with_account(user, %{"name" => "Garcia Home"}, %{
               "name" => "Joint",
               "current_balance" => "not a number"
             })

    assert %{current_balance: [_]} = errors_on(changeset)
    assert Accounts.list_households_for_user(user) == []
  end

  test "an invalid household is reported as such" do
    user = user_fixture()

    assert {:error, :household, changeset} =
             Finance.create_household_with_account(user, %{"name" => ""}, %{})

    assert %{name: [_]} = errors_on(changeset)
  end
end

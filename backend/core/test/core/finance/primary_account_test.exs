defmodule Core.Finance.PrimaryAccountTest do
  use Core.DataCase, async: true

  alias Core.{Accounts, Finance}
  alias Core.Finance.Account

  setup do
    %{user: user_fixture()}
  end

  defp account!(user, owner \\ nil, name, balance \\ "0") do
    {:ok, account} =
      Finance.create_account(user, owner || user, %{
        "name" => name,
        "kind" => "checking",
        "current_balance" => balance
      })

    account
  end

  defp primary_names(user, owner \\ nil) do
    {:ok, accounts} = Finance.list_accounts(user, owner || user)
    accounts |> Enum.filter(& &1.is_primary) |> Enum.map(& &1.name)
  end

  test "a scope's first account becomes primary, later ones don't", %{user: user} do
    first = account!(user, "Wallet")
    _second = account!(user, "Bank")

    assert Repo.get!(Account, first.id).is_primary
    assert primary_names(user) == ["Wallet"]
  end

  test "set_primary_account/2 moves the star and lists it first", %{user: user} do
    _wallet = account!(user, "Wallet")
    bank = account!(user, "Bank")

    {:ok, _} = Finance.set_primary_account(user, bank)

    assert primary_names(user) == ["Bank"]
    {:ok, [first | _]} = Finance.list_accounts(user, user)
    assert first.name == "Bank"
  end

  test "archiving the primary passes the star on; restoring fills an empty slot", %{user: user} do
    wallet = account!(user, "Wallet")
    _bank = account!(user, "Bank")

    {:ok, wallet} = Finance.archive_account(user, wallet)
    refute wallet.is_primary
    assert primary_names(user) == ["Bank"]
    assert {:error, :archived_account} = Finance.set_primary_account(user, wallet)

    solo = user_fixture()
    only = account!(solo, "Only")
    {:ok, only} = Finance.archive_account(solo, only)
    {:ok, only} = Finance.restore_account(solo, only)
    assert only.is_primary
  end

  test "each household keeps its own primary, separate from personal", %{user: user} do
    {:ok, household} = Accounts.create_household(user, %{"name" => "Home"})
    _mine = account!(user, "Mine")
    _joint = account!(user, household, "Joint")

    assert primary_names(user) == ["Mine"]
    assert primary_names(user, household) == ["Joint"]

    stranger = user_fixture()
    joint = Repo.get_by!(Account, name: "Joint")
    assert {:error, :forbidden} = Finance.set_primary_account(stranger, joint)
  end

  test "get_currency_summary/4 can narrow to one account", %{user: user} do
    wallet = account!(user, nil, "Wallet", "100")
    bank = account!(user, nil, "Bank", "100")
    today = Date.utc_today()

    for {account, amount} <- [{wallet, "10"}, {bank, "25"}] do
      {:ok, _} =
        Finance.create_transaction(user, %{
          "type" => "expense",
          "amount" => amount,
          "transaction_date" => today,
          "account_id" => account.id
        })
    end

    [%{amount: wallet_spent}] =
      Finance.get_currency_summary(user, today, today, account_id: wallet.id).expenses

    [%{amount: all_spent}] = Finance.get_currency_summary(user, today, today).expenses

    assert Decimal.equal?(wallet_spent, "10")
    assert Decimal.equal?(all_spent, "35")
  end
end

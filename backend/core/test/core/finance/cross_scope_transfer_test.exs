defmodule Core.Finance.CrossScopeTransferTest do
  use Core.DataCase, async: true

  alias Core.{Accounts, Finance}
  alias Core.Finance.Account

  setup do
    owner = user_fixture()
    member = user_fixture()
    {:ok, household} = Accounts.create_household(owner, %{"name" => "Garcia Home"})
    {:ok, _} = Accounts.add_household_member(owner, household, member)

    {:ok, personal} =
      Finance.create_account(owner, %{
        "name" => "My savings",
        "kind" => "savings",
        "current_balance" => "1000.00"
      })

    {:ok, shared} =
      Finance.create_account(owner, household, %{
        "name" => "Household checking",
        "kind" => "checking",
        "current_balance" => "200.00"
      })

    %{owner: owner, member: member, household: household, personal: personal, shared: shared}
  end

  defp transfer(actor, from, to, amount) do
    Finance.create_account_transfer(actor, actor, %{
      "from_account_id" => from.id,
      "to_account_id" => to.id,
      "amount" => amount
    })
  end

  defp balance(account), do: Repo.get!(Account, account.id).current_balance

  test "moves money from personal to household, each leg owned by its account's owner", ctx do
    assert {:ok, {out_leg, in_leg}} = transfer(ctx.owner, ctx.personal, ctx.shared, "300.00")

    assert out_leg.user_id == ctx.owner.id and is_nil(out_leg.household_id)
    assert in_leg.household_id == ctx.household.id and is_nil(in_leg.user_id)
    assert out_leg.counterpart_transaction_id == in_leg.id
    assert in_leg.counterpart_transaction_id == out_leg.id

    assert Decimal.equal?(balance(ctx.personal), "700.00")
    assert Decimal.equal?(balance(ctx.shared), "500.00")
  end

  test "works household to personal too", ctx do
    assert {:ok, _} = transfer(ctx.owner, ctx.shared, ctx.personal, "50.00")
    assert Decimal.equal?(balance(ctx.shared), "150.00")
    assert Decimal.equal?(balance(ctx.personal), "1050.00")
  end

  test "a transfer is neither income nor spending for either scope", ctx do
    {:ok, _} = transfer(ctx.owner, ctx.personal, ctx.shared, "300.00")
    today = Date.utc_today()

    for owner <- [ctx.owner, ctx.household] do
      summary =
        Finance.get_currency_summary(
          owner,
          Date.beginning_of_month(today),
          Date.end_of_month(today)
        )

      assert summary.income == []
      assert summary.expenses == []
    end
  end

  test "rejects accounts the actor cannot access", ctx do
    outsider = user_fixture()

    {:ok, theirs} =
      Finance.create_account(outsider, %{
        "name" => "Theirs",
        "kind" => "checking",
        "current_balance" => "10.00"
      })

    # outsider can't reach the household account, and can't push into it either
    assert {:error, :invalid_account_scope} = transfer(outsider, theirs, ctx.shared, "5.00")
    # a member can't reach the owner's personal account
    assert {:error, :invalid_account_scope} =
             transfer(ctx.member, ctx.shared, ctx.personal, "5.00")
  end

  test "rejects currency mismatches across scopes", ctx do
    {:ok, usd} =
      Finance.create_account(ctx.owner, ctx.household, %{
        "name" => "USD pot",
        "kind" => "savings",
        "currency" => "USD",
        "current_balance" => "0"
      })

    assert {:error, :currency_mismatch} = transfer(ctx.owner, ctx.personal, usd, "10.00")
  end

  test "deleting a cross-scope transfer needs access to both scopes", ctx do
    {:ok, {_out_leg, in_leg}} = transfer(ctx.owner, ctx.personal, ctx.shared, "300.00")

    # the member can see the household leg but not the owner's personal leg
    assert {:error, :forbidden} = Finance.delete_transaction(ctx.member, in_leg)
    assert Decimal.equal?(balance(ctx.personal), "700.00")

    # the owner can, and both balances are restored
    assert {:ok, _} = Finance.delete_transaction(ctx.owner, in_leg)
    assert Decimal.equal?(balance(ctx.personal), "1000.00")
    assert Decimal.equal?(balance(ctx.shared), "200.00")
  end

  test "creating and deleting a cross-scope transfer notifies both scopes", ctx do
    {owner_id, household_id} = {ctx.owner.id, ctx.household.id}
    :ok = Finance.subscribe(ctx.owner)

    {:ok, {out_leg, _in_leg}} =
      Task.async(fn -> transfer(ctx.owner, ctx.personal, ctx.shared, "10.00") end) |> Task.await()

    assert_receive {:finance_changed, {:user, ^owner_id}}
    assert_receive {:finance_changed, {:household, ^household_id}}

    {:ok, _} =
      Task.async(fn -> Finance.delete_transaction(ctx.owner, out_leg) end) |> Task.await()

    assert_receive {:finance_changed, {:user, ^owner_id}}
    assert_receive {:finance_changed, {:household, ^household_id}}
  end
end

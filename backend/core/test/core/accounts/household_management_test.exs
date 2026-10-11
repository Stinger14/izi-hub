defmodule Core.Accounts.HouseholdManagementTest do
  use Core.DataCase, async: true

  alias Core.{Accounts, Finance}
  alias Core.Accounts.{Household, HouseholdMember}
  alias Core.Finance.Account

  setup do
    owner = user_fixture()
    member = user_fixture()
    outsider = user_fixture()
    {:ok, household} = Accounts.create_household(owner, %{"name" => "Garcia Home"})
    {:ok, _} = Accounts.add_household_member(owner, household, member)
    %{owner: owner, member: member, outsider: outsider, household: household}
  end

  test "the owner renames; others can't, and the slug stays", ctx do
    assert {:ok, renamed} =
             Accounts.rename_household(ctx.owner, ctx.household, %{
               "name" => "Casa Garcia",
               "slug" => "hijack"
             })

    assert renamed.name == "Casa Garcia"
    assert renamed.slug == ctx.household.slug

    assert {:error, :forbidden} =
             Accounts.rename_household(ctx.member, ctx.household, %{"name" => "Mine"})
  end

  test "the owner removes a member, who loses access", ctx do
    assert {:ok, _} = Accounts.remove_household_member(ctx.owner, ctx.household, ctx.member.id)
    refute Accounts.user_household?(ctx.member, ctx.household.id)
    assert Accounts.list_households_for_user(ctx.member) == []

    # and can be added back later
    assert {:ok, _} = Accounts.add_household_member(ctx.owner, ctx.household, ctx.member)
  end

  test "nobody can remove the owner, and members can't remove anyone", ctx do
    assert {:error, :cannot_remove_owner} =
             Accounts.remove_household_member(ctx.owner, ctx.household, ctx.owner.id)

    assert {:error, :forbidden} =
             Accounts.remove_household_member(ctx.member, ctx.household, ctx.owner.id)

    assert {:error, :not_found} =
             Accounts.remove_household_member(ctx.owner, ctx.household, ctx.outsider.id)
  end

  test "members can leave; the owner can't", ctx do
    assert {:ok, _} = Accounts.leave_household(ctx.member, ctx.household)
    refute Accounts.user_household?(ctx.member, ctx.household.id)
    assert {:error, :owner_cannot_leave} = Accounts.leave_household(ctx.owner, ctx.household)
  end

  test "deleting needs the owner and the exact name, then removes everything it owned", ctx do
    {:ok, shared} =
      Finance.create_account(ctx.owner, ctx.household, %{
        "name" => "Shared",
        "kind" => "checking",
        "current_balance" => "10"
      })

    assert {:error, :forbidden} =
             Accounts.delete_household(ctx.member, ctx.household, "Garcia Home")

    assert {:error, :confirmation_mismatch} =
             Accounts.delete_household(ctx.owner, ctx.household, "Garcia")

    assert Repo.get(Household, ctx.household.id)

    assert {:ok, _} = Accounts.delete_household(ctx.owner, ctx.household, "  garcia home ")
    refute Repo.get(Household, ctx.household.id)
    refute Repo.get(Account, shared.id)
    assert Repo.all(from m in HouseholdMember, where: m.household_id == ^ctx.household.id) == []
  end

  test "changes notify everyone watching the household", ctx do
    household_id = ctx.household.id
    :ok = Finance.subscribe(ctx.member)

    {:ok, _} =
      Task.async(fn ->
        Accounts.rename_household(ctx.owner, ctx.household, %{"name" => "Casa"})
      end)
      |> Task.await()

    assert_receive {:finance_changed, {:household, ^household_id}}

    {:ok, _} =
      Task.async(fn ->
        Accounts.remove_household_member(ctx.owner, ctx.household, ctx.member.id)
      end)
      |> Task.await()

    assert_receive {:finance_changed, {:household, ^household_id}}
  end
end

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

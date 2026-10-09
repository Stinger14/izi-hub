defmodule Core.Finance.LiveUpdatesTest do
  use Core.DataCase, async: true

  alias Core.{Accounts, Finance}

  # The writing process never gets its own echo (broadcast_from), so writes
  # here run in another process, the way a different LiveView or the
  # ingestion API would.
  defp elsewhere(fun), do: fun |> Task.async() |> Task.await()

  defp expense(user, owner \\ nil, attrs \\ %{}) do
    elsewhere(fn ->
      Finance.create_transaction(
        user,
        owner || user,
        Map.merge(
          %{
            "amount" => "20.00",
            "type" => "expense",
            "transaction_date" => Date.to_iso8601(Date.utc_today())
          },
          attrs
        )
      )
    end)
  end

  test "a personal write reaches only that user's subscribers" do
    me = user_fixture()
    other = user_fixture()
    :ok = Finance.subscribe(me)
    my_id = me.id

    {:ok, _} = expense(me)
    assert_receive {:finance_changed, {:user, ^my_id}}

    {:ok, _} = expense(other)
    refute_receive {:finance_changed, _}
  end

  test "a household write reaches every member and no one else" do
    owner = user_fixture()
    member = user_fixture()
    outsider = user_fixture()
    {:ok, household} = Accounts.create_household(owner, %{"name" => "Garcia Home"})
    {:ok, _} = Accounts.add_household_member(owner, household, member)
    household_id = household.id
    parent = self()

    listen = fn user ->
      # Task (not spawn) so the listener inherits the test's DB sandbox access
      Task.start_link(fn ->
        :ok = Finance.subscribe(user)
        send(parent, {:subscribed, user.id})

        receive do
          {:finance_changed, ref} -> send(parent, {:heard, user.id, ref})
        after
          500 -> send(parent, {:silent, user.id})
        end
      end)
    end

    for user <- [owner, member, outsider] do
      listen.(user)
      user_id = user.id
      assert_receive {:subscribed, ^user_id}
    end

    {:ok, _} = expense(member, household)

    {owner_id, member_id, outsider_id} = {owner.id, member.id, outsider.id}
    assert_receive {:heard, ^owner_id, {:household, ^household_id}}
    assert_receive {:heard, ^member_id, {:household, ^household_id}}
    assert_receive {:silent, ^outsider_id}, 1_000
  end

  test "failed writes do not broadcast" do
    user = user_fixture()
    :ok = Finance.subscribe(user)

    assert {:error, _} = expense(user, nil, %{"amount" => "not money"})
    refute_receive {:finance_changed, _}
  end

  test "the writing process gets no echo" do
    user = user_fixture()
    :ok = Finance.subscribe(user)

    {:ok, _} =
      Finance.create_transaction(user, %{
        "amount" => "5.00",
        "type" => "expense",
        "transaction_date" => Date.to_iso8601(Date.utc_today())
      })

    refute_receive {:finance_changed, _}
  end

  test "a transfer broadcasts once" do
    user = user_fixture()

    {:ok, from} =
      Finance.create_account(user, %{
        "name" => "Checking",
        "kind" => "checking",
        "current_balance" => "500.00"
      })

    {:ok, to} =
      Finance.create_account(user, %{
        "name" => "Savings",
        "kind" => "savings",
        "current_balance" => "0.00"
      })

    :ok = Finance.subscribe(user)

    {:ok, _} =
      elsewhere(fn ->
        Finance.create_account_transfer(user, user, %{
          "from_account_id" => from.id,
          "to_account_id" => to.id,
          "amount" => "100.00"
        })
      end)

    assert_receive {:finance_changed, _}
    refute_receive {:finance_changed, _}
  end

  test "a debt payment broadcasts once, after its transaction commits" do
    user = user_fixture()

    {:ok, debt} =
      Finance.create_debt(user, %{
        "name" => "Card",
        "kind" => "credit_card",
        "current_balance" => "1000.00",
        "minimum_payment" => "50.00"
      })

    :ok = Finance.subscribe(user)

    {:ok, _} =
      elsewhere(fn ->
        Finance.record_debt_payment(user, debt, %{
          "amount" => "50.00",
          "payment_date" => Date.to_iso8601(Date.utc_today()),
          "create_transaction" => "true"
        })
      end)

    assert_receive {:finance_changed, _}
    refute_receive {:finance_changed, _}
  end

  test "email ingestion broadcasts to the token owner" do
    user = user_fixture()
    :ok = Finance.subscribe(user)
    user_id = user.id

    {:ok, _} =
      elsewhere(fn ->
        Finance.ingest_email_transaction_candidate(user, %{
          "provider" => "bank_email",
          "message_id" => "<live-#{System.unique_integer([:positive])}@bank.com>",
          "from" => "alerts@bank.com",
          "subject" => "Card purchase alert",
          "received_at" => DateTime.utc_now(),
          "text_body" => "Card purchase alert\nMerchant: Cafe Central\nAmount: USD 54.25\n",
          "html_body" => nil
        })
      end)

    assert_receive {:finance_changed, {:user, ^user_id}}
  end
end

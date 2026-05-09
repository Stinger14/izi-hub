defmodule Core.Finance.EmailIngestionTest do
  use Core.DataCase, async: true

  alias Core.Accounts
  alias Core.Finance

  test "ingests a supported bank alert into a pending review transaction" do
    user = user_fixture()

    assert {:ok, transaction} =
             Finance.ingest_email_transaction_candidate(user, %{
               "provider" => "bank_email",
               "message_id" => "<msg-1@bank.com>",
               "from" => "alerts@bank.com",
               "subject" => "Card purchase alert",
               "received_at" => ~U[2026-04-25 14:30:00Z],
               "text_body" => """
               Card purchase alert
               Merchant: Cafe Central
               Amount: USD 54.25
               """,
               "html_body" => nil
             })

    assert transaction.status == "pending_review"
    assert transaction.source == "email"
    assert transaction.external_id == "<msg-1@bank.com>"
    assert transaction.amount == Decimal.new("54.25")
    assert transaction.type == "expense"
    assert transaction.merchant == "Cafe Central"
    assert transaction.transaction_date == ~D[2026-04-25]
    assert transaction.review_reason == "Parsed from bank email"

    assert [attempt] = Finance.list_email_ingestions_for_user(user)
    assert attempt.status == "created"
    assert attempt.provider == "bank_email"
    assert attempt.message_id == "<msg-1@bank.com>"
    assert attempt.sender == "alerts@bank.com"
    assert attempt.parser_name == "Core.Finance.Parsers.BankAlertParser"
    assert attempt.transaction_id == transaction.id
    assert attempt.body_snippet =~ "Merchant: Cafe Central"
  end

  test "duplicate message ids are treated as duplicates" do
    user = user_fixture()

    attrs = %{
      "provider" => "bank_email",
      "message_id" => "<msg-2@bank.com>",
      "from" => "alerts@bank.com",
      "subject" => "Deposit alert",
      "received_at" => ~U[2026-04-25 14:30:00Z],
      "text_body" => """
      Deposit alert
      From Payroll
      Amount: USD 1200.00
      """,
      "html_body" => nil
    }

    assert {:ok, _transaction} = Finance.ingest_email_transaction_candidate(user, attrs)
    assert {:ok, :duplicate} = Finance.ingest_email_transaction_candidate(user, attrs)
    assert length(Finance.list_pending_transactions_for_user(user)) == 1

    attempts = Finance.list_email_ingestions_for_user(user)
    assert Enum.map(attempts, & &1.status) |> Enum.sort() == ["created", "duplicate"]
    assert Enum.all?(attempts, &(&1.message_id == "<msg-2@bank.com>"))
    assert Enum.all?(attempts, & &1.transaction_id)
  end

  test "unsupported sender returns unsupported email" do
    user = user_fixture()

    assert {:error, :unsupported_email} =
             Finance.ingest_email_transaction_candidate(user, %{
               "provider" => "bank_email",
               "message_id" => "<msg-3@unknown.com>",
               "from" => "newsletter@example.com",
               "subject" => "Weekly update",
               "received_at" => ~U[2026-04-25 14:30:00Z],
               "text_body" => "hello there",
               "html_body" => nil
             })

    assert [attempt] = Finance.list_email_ingestions_for_user(user)
    assert attempt.status == "unsupported_email"
    assert attempt.error_reason == "unsupported_email"
    assert attempt.sender == "newsletter@example.com"
    assert is_nil(attempt.transaction_id)
  end

  test "unparseable supported email returns unparseable email" do
    user = user_fixture()

    assert {:error, :unparseable_email} =
             Finance.ingest_email_transaction_candidate(user, %{
               "provider" => "bank_email",
               "message_id" => "<msg-4@bank.com>",
               "from" => "alerts@bank.com",
               "subject" => "Card purchase alert",
               "received_at" => ~U[2026-04-25 14:30:00Z],
               "text_body" => "Merchant: Cafe Central",
               "html_body" => nil
             })

    assert [attempt] = Finance.list_email_ingestions_for_user(user)
    assert attempt.status == "unparseable_email"
    assert attempt.error_reason == "amount_not_found"
    assert attempt.parser_name == "Core.Finance.Parsers.BankAlertParser"
    assert is_nil(attempt.transaction_id)
  end

  test "pending review transactions from email do not affect health until confirmed" do
    user = user_fixture()

    assert {:ok, transaction} =
             Finance.ingest_email_transaction_candidate(user, %{
               "provider" => "bank_email",
               "message_id" => "<msg-5@bank.com>",
               "from" => "alerts@bank.com",
               "subject" => "Card purchase alert",
               "received_at" => ~U[2026-04-25 14:30:00Z],
               "text_body" => """
               Card purchase alert
               Merchant: Cafe Central
               Amount: USD 54.25
               """,
               "html_body" => nil
             })

    health_before = Finance.get_financial_health(user, today: ~D[2026-04-25])
    assert health_before.current_month.expenses == Decimal.new("0")

    assert {:ok, _confirmed} = Finance.confirm_transaction(user, transaction)

    health_after = Finance.get_financial_health(user, today: ~D[2026-04-25])
    assert health_after.current_month.expenses == Decimal.new("54.25")
  end

  defp user_fixture do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        email: "finance_ingestion_user_#{unique}@example.com",
        password: "Password123!",
        username: "finance_ingestion_user_#{unique}",
        full_name: "Finance Ingestion User"
      })

    user
  end
end

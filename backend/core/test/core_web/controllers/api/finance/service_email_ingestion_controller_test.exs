defmodule CoreWeb.Api.Finance.ServiceEmailIngestionControllerTest do
  use CoreWeb.ConnCase, async: true

  alias Core.Accounts
  alias Core.Finance

  setup %{conn: conn} do
    api_key = Application.fetch_env!(:core, :finance_ingestion_api_key)
    conn = put_req_header(conn, "authorization", "Bearer " <> api_key)
    %{conn: conn}
  end

  test "rejects requests with a missing authorization header", %{conn: conn} do
    conn =
      conn
      |> delete_req_header("authorization")
      |> post(~p"/api/service/finance/email-ingestion", %{
        email: valid_email_payload(),
        ingestion_token: "whatever"
      })

    assert json_response(conn, :unauthorized)["error"] == "unauthenticated"
  end

  test "rejects requests with the wrong bearer token", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer wrong-token")
      |> post(~p"/api/service/finance/email-ingestion", %{
        email: valid_email_payload(),
        ingestion_token: "whatever"
      })

    assert json_response(conn, :unauthorized)["error"] == "unauthenticated"
  end

  test "returns 400 when the ingestion_token is missing", %{conn: conn} do
    conn =
      post(conn, ~p"/api/service/finance/email-ingestion", %{email: valid_email_payload()})

    assert json_response(conn, :bad_request)["error"] == "missing_ingestion_token"
  end

  test "returns 401 when the ingestion_token is unknown", %{conn: conn} do
    conn =
      post(conn, ~p"/api/service/finance/email-ingestion", %{
        email: valid_email_payload(),
        ingestion_token: "unknown-token"
      })

    assert json_response(conn, :unauthorized)["error"] == "invalid_ingestion_token"
  end

  test "creates a pending review transaction for the token's owner", %{conn: conn} do
    user = user_fixture()
    {:ok, token} = Finance.create_ingestion_token(user)

    conn =
      post(conn, ~p"/api/service/finance/email-ingestion", %{
        email: valid_email_payload(),
        ingestion_token: token.token
      })

    assert %{"status" => "created", "transaction" => transaction_json} =
             json_response(conn, :created)

    assert transaction_json["status"] == "pending_review"
    assert transaction_json["source"] == "email"
    assert transaction_json["amount"] == "54.25"

    [transaction] = Finance.list_pending_transactions_for_user(user)
    assert transaction.external_id == "<api-msg-1@bank.com>"
    assert transaction.merchant == "Cafe Central"
    assert transaction.transaction_date == ~D[2026-04-25]
  end

  test "returns duplicate for repeated message ids", %{conn: conn} do
    user = user_fixture()
    {:ok, token} = Finance.create_ingestion_token(user)
    payload = %{email: valid_email_payload(), ingestion_token: token.token}

    first_conn = post(conn, ~p"/api/service/finance/email-ingestion", payload)
    assert %{"status" => "created"} = json_response(first_conn, :created)

    second_conn = post(conn, ~p"/api/service/finance/email-ingestion", payload)
    assert %{"status" => "duplicate"} = json_response(second_conn, :ok)

    assert length(Finance.list_pending_transactions_for_user(user)) == 1
  end

  test "returns unsupported_email for unsupported sender", %{conn: conn} do
    user = user_fixture()
    {:ok, token} = Finance.create_ingestion_token(user)
    payload = %{valid_email_payload() | "from" => "newsletter@example.com"}

    conn =
      post(conn, ~p"/api/service/finance/email-ingestion", %{
        email: payload,
        ingestion_token: token.token
      })

    assert json_response(conn, :unprocessable_entity)["error"] == "unsupported_email"
  end

  test "returns unparseable_email for supported sender with missing amount", %{conn: conn} do
    user = user_fixture()
    {:ok, token} = Finance.create_ingestion_token(user)
    payload = %{valid_email_payload() | "text_body" => "Merchant: Cafe Central"}

    conn =
      post(conn, ~p"/api/service/finance/email-ingestion", %{
        email: payload,
        ingestion_token: token.token
      })

    assert json_response(conn, :unprocessable_entity)["error"] == "unparseable_email"
  end

  defp valid_email_payload do
    %{
      "provider" => "bank_email",
      "message_id" => "<api-msg-1@bank.com>",
      "from" => "alerts@bank.com",
      "subject" => "Card purchase alert",
      "received_at" => "2026-04-25T14:30:00Z",
      "text_body" => """
      Card purchase alert
      Merchant: Cafe Central
      Amount: USD 54.25
      """,
      "html_body" => nil
    }
  end

  defp user_fixture do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        email: "finance_service_api_user_#{unique}@example.com",
        password: "Password123!",
        username: "finance_service_api_user_#{unique}",
        full_name: "Finance Service API User"
      })

    user
  end
end

defmodule CoreWeb.Api.Finance.ServiceEmailIngestionControllerTest do
  use CoreWeb.ConnCase, async: true

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

  # Parsing outcomes are covered in Core.Finance.EmailIngestionTest; this only
  # checks that each one maps to the right HTTP status and JSON body.
  test "maps ingestion outcomes to HTTP responses", %{conn: conn} do
    user = user_fixture()
    {:ok, token} = Finance.create_ingestion_token(user)

    ingest = fn email ->
      post(conn, ~p"/api/service/finance/email-ingestion", %{
        email: email,
        ingestion_token: token.token
      })
    end

    assert %{"status" => "created"} = ingest.(valid_email_payload()) |> json_response(:created)
    assert %{"status" => "duplicate"} = ingest.(valid_email_payload()) |> json_response(:ok)

    assert ingest.(%{valid_email_payload() | "from" => "newsletter@example.com"})
           |> json_response(:unprocessable_entity)
           |> Map.fetch!("error") == "unsupported_email"

    assert ingest.(%{valid_email_payload() | "text_body" => "Merchant: Cafe Central"})
           |> json_response(:unprocessable_entity)
           |> Map.fetch!("error") == "unparseable_email"

    assert length(Finance.list_pending_transactions_for_user(user)) == 1
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
end

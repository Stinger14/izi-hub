defmodule CoreWeb.Admin.FinOpsLiveTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.Accounts
  alias Core.Finance
  alias Core.Repo

  test "redirects unauthenticated users to login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/hub?auth=login"}}} = live(conn, ~p"/admin/finops")
  end

  test "redirects non-admin users", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)

    assert {:error, {:redirect, %{to: "/hub"}}} = live(conn, ~p"/admin/finops")
  end

  test "renders the finops console for admins", %{conn: conn} do
    admin = admin_fixture()
    conn = init_test_session(conn, user_id: admin.id)

    assert {:ok, _view, html} = live(conn, ~p"/admin/finops")

    assert html =~ "FinOps"
    assert html =~ "Sample email ingestion"
    assert html =~ "Load expense preset"
  end

  test "ingests a sample bank email for a target user", %{conn: conn} do
    admin = admin_fixture()
    target_user = user_fixture()
    conn = init_test_session(conn, user_id: admin.id)

    {:ok, view, _html} = live(conn, ~p"/admin/finops")

    html =
      view
      |> form("form[phx-submit=\"ingest_sample\"]",
        finops: %{
          "target_email" => target_user.email,
          "provider" => "bank_email",
          "from" => "alerts@bank.com",
          "subject" => "Card purchase alert",
          "message_id" => "<finops-1@bank.com>",
          "received_at" => "2026-04-25T14:30",
          "text_body" => """
          Card purchase alert
          Merchant: Cafe Central
          Amount: USD 54.25
          """,
          "html_body" => ""
        }
      )
      |> render_submit()

    assert html =~ target_user.email

    [transaction] = Finance.list_pending_transactions_for_user(target_user)
    assert transaction.amount == Decimal.new("54.25")
    assert transaction.external_id == "<finops-1@bank.com>"
    assert transaction.merchant == "Cafe Central"
  end

  defp user_fixture do
    {:ok, user} =
      Accounts.register_user(%{
        email: "finops_user_#{System.unique_integer([:positive])}@example.com",
        password: "Password123!",
        username: "finops_user_#{System.unique_integer([:positive])}",
        full_name: "FinOps User"
      })

    user
  end

  defp admin_fixture do
    user = user_fixture()

    user
    |> Ecto.Changeset.change(%{role: "admin", is_active: true})
    |> Repo.update!()
  end
end

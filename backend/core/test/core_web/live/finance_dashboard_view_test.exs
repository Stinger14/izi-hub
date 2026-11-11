defmodule CoreWeb.FinanceDashboardViewTest do
  @moduledoc "The Overview's Show picker and the primary account star."
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.Finance

  setup %{conn: conn} do
    user = user_fixture()
    wallet = account!(user, "Wallet", "1000")
    bank = account!(user, "Bank", "5000")
    %{conn: log_in_user(conn, user), user: user, wallet: wallet, bank: bank}
  end

  defp account!(user, name, balance) do
    {:ok, account} =
      Finance.create_account(user, %{
        "name" => name,
        "kind" => "checking",
        "current_balance" => balance
      })

    account
  end

  test "the Overview opens on the primary account", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/finance")

    assert has_element?(view, "#dashboard-view option[selected]", "Wallet")
    assert view |> element("#dashboard-view-form") |> has_element?()
    refute has_element?(view, ~s(select[name="currency"]))
  end

  test "Show switches the board and lands in the URL", %{conn: conn, bank: bank} do
    {:ok, view, _html} = live(conn, ~p"/finance")

    view |> form("#dashboard-view-form", %{"view" => bank.id}) |> render_change()
    assert_patch(view, ~p"/finance?view=#{bank.id}")
    assert has_element?(view, "#dashboard-view option[selected]", "Bank")
    assert render(view) =~ "DOP$ 5,000.00"

    view |> form("#dashboard-view-form", %{"view" => "all"}) |> render_change()
    assert_patch(view, ~p"/finance?view=all")
    assert render(view) =~ "Total balance"
    assert render(view) =~ "DOP$ 6,000.00"
  end

  test "the star makes another account primary", %{conn: conn, user: user, bank: bank} do
    {:ok, view, _html} = live(conn, ~p"/finance")
    render_click(view, "show_section", %{"section" => "accounts"})

    html = view |> element(~s(button[aria-label="Make Bank primary"])) |> render_click()

    assert html =~ "Bank is now your primary account"
    assert Enum.find(Finance.list_accounts_for_user(user), & &1.is_primary).id == bank.id
  end

  test "new transactions default to the account on the board", %{conn: conn, bank: bank} do
    {:ok, view, _html} = live(conn, ~p"/finance?view=#{bank.id}")
    render_click(view, "open_focus_panel", %{"panel" => "transaction"})

    assert has_element?(
             view,
             ~s(select[name="transaction[account_id]"] option[value="#{bank.id}"][selected])
           )
  end
end

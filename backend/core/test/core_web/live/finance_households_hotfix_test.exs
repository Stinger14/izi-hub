defmodule CoreWeb.FinanceHouseholdsHotfixTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.{Accounts, Finance}

  def invite_url(token), do: "/invites/#{token}"

  defp account!(user, owner, name, balance, currency \\ "DOP") do
    {:ok, account} =
      Finance.create_account(user, owner, %{
        "name" => name,
        "kind" => "checking",
        "currency" => currency,
        "current_balance" => balance
      })

    account
  end

  describe "scope switcher" do
    test "lists Personal and every household with balances, and switches", %{conn: conn} do
      user = user_fixture()
      {:ok, home} = Accounts.create_household(user, %{"name" => "Garcia Home"})
      {:ok, beach} = Accounts.create_household(user, %{"name" => "Beach House"})
      account!(user, user, "Wallet", "120.00")
      account!(user, home, "Home fund", "2500.00")

      {:ok, view, _html} = live(log_in_user(conn, user), ~p"/finance")

      personal = view |> element("#scope-option-personal") |> render()
      assert personal =~ "Personal"
      assert personal =~ "120.00"
      assert personal =~ ~s(aria-checked="true")

      home_option = view |> element("#scope-option-#{home.id}") |> render()
      assert home_option =~ "Garcia Home"
      assert home_option =~ "2,500.00"
      assert home_option =~ "Owner · 1 member · 1 account"

      assert view |> element("#scope-option-#{beach.id}") |> render() =~ "No accounts"

      view |> element("#scope-option-#{home.id}") |> render_click()

      assert view |> element("#scope-option-#{home.id}") |> render() =~ ~s(aria-checked="true")
      assert view |> element("#scope-switcher-trigger") |> render() =~ "Garcia Home"
    end

    test "?household= opens that household", %{conn: conn} do
      user = user_fixture()
      {:ok, _first} = Accounts.create_household(user, %{"name" => "Alpha Home"})
      {:ok, second} = Accounts.create_household(user, %{"name" => "Zulu Home"})

      {:ok, view, _html} =
        live(log_in_user(conn, user), ~p"/finance?household=#{second.id}")

      assert view |> element("#scope-switcher-trigger") |> render() =~ "Zulu Home"
    end
  end

  describe "creating a household with a starting account" do
    test "the new household's dashboard shows the starting balance", %{conn: conn} do
      user = user_fixture()
      account!(user, user, "Wallet", "50.00")
      {:ok, view, _html} = live(log_in_user(conn, user), ~p"/finance")

      view |> element("#scope-new-household") |> render_click()

      html =
        view
        |> form("#create-household-form", %{
          "household" => %{"name" => "Garcia Home"},
          "starting_account" => %{
            "name" => "Joint checking",
            "current_balance" => "3200.00",
            "kind" => "checking",
            "currency" => "USD"
          }
        })
        |> render_submit()

      assert html =~ "Household created"
      [household] = Accounts.list_households_for_user(user)
      assert {:ok, [%{name: "Joint checking"}]} = Finance.list_accounts(user, household)

      assert view |> element("#scope-switcher-trigger") |> render() =~ "Garcia Home"
      assert html =~ "3,200.00"
      refute has_element?(view, "#no-accounts-notice")
    end

    test "an invalid starting balance keeps the form open with the error", %{conn: conn} do
      user = user_fixture()
      {:ok, view, _html} = live(log_in_user(conn, user), ~p"/finance")
      view |> element("#scope-new-household") |> render_click()

      view
      |> form("#create-household-form", %{
        "household" => %{"name" => "Garcia Home"},
        "starting_account" => %{"name" => "Joint", "current_balance" => "lots"}
      })
      |> render_submit()

      assert has_element?(view, "#household-starting-account", "is invalid")
      assert Accounts.list_households_for_user(user) == []
    end

    test "a household without accounts says so", %{conn: conn} do
      user = user_fixture()
      {:ok, household} = Accounts.create_household(user, %{"name" => "Garcia Home"})

      {:ok, view, _html} = live(log_in_user(conn, user), ~p"/finance?household=#{household.id}")

      assert view |> element("#no-accounts-notice") |> render() =~
               "Garcia Home has no accounts yet"
    end
  end

  describe "invitations" do
    setup do
      owner = user_fixture(%{full_name: "Olivia Owner"})
      {:ok, household} = Accounts.create_household(owner, %{"name" => "Garcia Home"})
      %{owner: owner, household: household}
    end

    test "a member invites by email and gets a copyable link", %{conn: conn} = ctx do
      {:ok, view, _html} =
        live(log_in_user(conn, ctx.owner), ~p"/finance?household=#{ctx.household.id}")

      render_click(view, "open_household_panel", %{})

      view
      |> form("#household-invite-form", invitation: %{email: "partner@example.com"})
      |> render_submit()

      link = view |> element("#last-invite-link") |> render()
      assert link =~ "partner@example.com"
      assert link =~ "/invites/"
      assert has_element?(view, "#household-invitations li", "partner@example.com")

      [invitation] = Accounts.list_household_invitations(ctx.owner, ctx.household)
      view |> element("#household-invitation-#{invitation.id} button", "Cancel") |> render_click()
      refute has_element?(view, "#household-invitations li", "partner@example.com")
    end

    test "inviting a current member shows an error", %{conn: conn} = ctx do
      {:ok, view, _html} =
        live(log_in_user(conn, ctx.owner), ~p"/finance?household=#{ctx.household.id}")

      render_click(view, "open_household_panel", %{})

      html =
        view
        |> form("#household-invite-form", invitation: %{email: ctx.owner.email})
        |> render_submit()

      assert html =~ "is already a member"
    end

    test "the invitee sees it live, joins, and lands in the household", %{conn: conn} = ctx do
      invitee = user_fixture(%{email: "invitee@example.com"})
      {:ok, view, html} = live(log_in_user(conn, invitee), ~p"/finance")
      refute html =~ "Household invitations"

      # Sent from another process, like the inviter's own page.
      Task.async(fn ->
        Accounts.invite_to_household(
          ctx.owner,
          ctx.household,
          "invitee@example.com",
          &__MODULE__.invite_url/1
        )
      end)
      |> Task.await()

      assert view |> element("#finance-invitations") |> render() =~
               "Olivia Owner"

      [invitation] = Accounts.list_pending_invitations_for_user(invitee)
      html = view |> element("#invitation-#{invitation.id} button", "Join") |> render_click()

      assert html =~ "You joined Garcia Home"
      assert Accounts.user_household?(invitee, ctx.household.id)
      assert view |> element("#scope-switcher-trigger") |> render() =~ "Garcia Home"
      refute has_element?(view, "#finance-invitations")
    end

    test "the hub's finance card links to pending invitations", %{conn: conn} = ctx do
      invitee = user_fixture(%{email: "invitee@example.com"})

      {:ok, _invitation, _url} =
        Accounts.invite_to_household(
          ctx.owner,
          ctx.household,
          "invitee@example.com",
          &__MODULE__.invite_url/1
        )

      {:ok, view, _html} = live(log_in_user(conn, invitee), ~p"/hub")
      assert view |> element("#hub-household-invitations") |> render() =~ "1 household invitation"
    end
  end

  describe "transfers between personal and household accounts" do
    test "the form lists both scopes and moves both balances", %{conn: conn} do
      user = user_fixture()
      {:ok, household} = Accounts.create_household(user, %{"name" => "Garcia Home"})
      wallet = account!(user, user, "Wallet", "1000.00")
      fund = account!(user, household, "Home fund", "0.00")

      {:ok, view, _html} = live(log_in_user(conn, user), ~p"/finance")
      render_click(view, "open_focus_panel", %{"panel" => "transfer"})

      form_html = view |> element("#transfer-panel-form") |> render()
      assert form_html =~ ~s(label="Personal")
      assert form_html =~ ~s(label="Garcia Home")

      view
      |> form("#transfer-panel-form",
        transfer: %{from_account_id: wallet.id, to_account_id: fund.id, amount: "250.00"}
      )
      |> render_submit()

      assert Decimal.equal?(
               Finance.get_account!(user, user, wallet.id).current_balance,
               Decimal.new("750.00")
             )

      assert Decimal.equal?(
               Finance.get_account!(user, household, fund.id).current_balance,
               Decimal.new("250.00")
             )
    end

    test "different currencies explain why", %{conn: conn} do
      user = user_fixture()
      {:ok, household} = Accounts.create_household(user, %{"name" => "Garcia Home"})
      wallet = account!(user, user, "Wallet", "1000.00", "DOP")
      fund = account!(user, household, "Dollar fund", "0.00", "USD")

      {:ok, view, _html} = live(log_in_user(conn, user), ~p"/finance")
      render_click(view, "open_focus_panel", %{"panel" => "transfer"})

      html =
        view
        |> form("#transfer-panel-form",
          transfer: %{from_account_id: wallet.id, to_account_id: fund.id, amount: "10"}
        )
        |> render_submit()

      assert html =~ "Both accounts must use the same currency"
    end
  end
end

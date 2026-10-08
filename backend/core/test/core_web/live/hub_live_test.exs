defmodule CoreWeb.HubLiveTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.{Accounts, Finance}

  describe "/hub" do
    test "renders the dashboard widgets inside the hub theme", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/hub")

      assert html =~ "hub-shell"
      assert html =~ "Dashboard"
      assert html =~ "Your money, at a glance"
      assert html =~ "Developer stats"
      assert html =~ ~s(id="tasks")
      assert html =~ ~s(id="calendar")
      assert html =~ ~s(id="music")
      assert html =~ ~s(id="library")
      assert html =~ ~s(id="gmail")
    end

    test "orders the right rail calendar, music, library, gmail", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/hub")

      positions =
        Enum.map(~w(calendar music library gmail), fn id ->
          {index, _} = :binary.match(html, ~s(id="#{id}"))
          index
        end)

      assert positions == Enum.sort(positions)
    end

    test "switches the stats card between developer and creator", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/hub")
      assert html =~ "Developer stats"

      html = render_click(view, "set_stats_variant", %{"variant" => "creator"})
      assert html =~ "Creator stats"
      assert html =~ "Facebook stats are coming soon"
      refute html =~ "Developer stats"

      html = render_click(view, "set_stats_variant", %{"variant" => "developer"})
      assert html =~ "Developer stats"
    end

    test "ignores unknown stats variants", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/hub")

      html = render_click(view, "set_stats_variant", %{"variant" => "admin"})
      assert html =~ "Developer stats"
    end

    test "navigates calendar months", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/hub")
      today = Date.utc_today()
      current = Calendar.strftime(today, "%B %Y")
      previous = today |> Date.beginning_of_month() |> Date.add(-1) |> Calendar.strftime("%B %Y")

      assert render(view) =~ current
      assert view |> element("button[aria-label='Previous month']") |> render_click() =~ previous

      assert view |> element("button[aria-label='Next month']") |> render_click() =~ current
    end

    test "toggles the translator", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/hub")
      refute html =~ ~s(id="translator-popover")

      assert view |> element("button", "Translate") |> render_click() =~
               ~s(id="translator-popover")
    end
  end

  describe "/hub finance card" do
    test "asks guests to sign in", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/hub")
      assert html =~ "Sign in to see your balances"
    end

    test "points users without accounts to Finance", %{conn: conn} do
      conn = init_test_session(conn, user_id: user_fixture().id)
      {:ok, _view, html} = live(conn, ~p"/hub")

      assert html =~ "No accounts yet"
      assert html =~ "Add an account"
    end

    test "shows the live balance and this month's spending", %{conn: conn} do
      user = user_fixture()
      conn = init_test_session(conn, user_id: user.id)

      {:ok, _account} =
        Finance.create_account(user, %{
          "name" => "Main checking",
          "kind" => "checking",
          "current_balance" => "2000.00"
        })

      {:ok, _txn} =
        Finance.create_transaction(user, %{
          "amount" => "75.00",
          "type" => "expense",
          "description" => "Market",
          "transaction_date" => Date.to_iso8601(Date.utc_today())
        })

      {:ok, _view, html} = live(conn, ~p"/hub")

      assert html =~ "Total balance"
      assert html =~ "DOP$ 2,000.00"
      assert html =~ "Spent this month"
      assert html =~ "DOP$ 75.00"
      assert html =~ "1 active account"
      refute html =~ ~s(aria-label="Finance scope")
    end

    test "offers a household toggle to household members", %{conn: conn} do
      user = user_fixture()
      conn = init_test_session(conn, user_id: user.id)
      {:ok, _household} = Accounts.create_household(user, %{"name" => "Garcia Home"})

      {:ok, view, html} = live(conn, ~p"/hub")
      assert html =~ ~s(aria-label="Finance scope")

      html = render_click(view, "set_finance_scope", %{"scope" => "household"})
      assert html =~ "Finance · Garcia Home"
    end
  end

  describe "/hub developer card" do
    test "asks guests to sign in", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/hub")
      assert html =~ "Sign in to link your GitHub account."
    end

    test "links a GitHub username and shows its stats", %{conn: conn} do
      user = user_fixture()
      conn = init_test_session(conn, user_id: user.id)
      login = "hubtest-#{System.unique_integer([:positive])}"

      seed_developer_stats(
        login,
        {:ok,
         %{
           login: login,
           public_repos: 12,
           contributions_last_year: 345,
           last_active_on: Date.utc_today()
         }}
      )

      {:ok, view, html} = live(conn, ~p"/hub")
      assert html =~ "Connect GitHub"

      view
      |> form("#github-link-form", github: %{github_username: "@" <> login})
      |> render_submit()

      html = render_async(view)

      assert html =~ "345"
      assert html =~ "12"
      assert html =~ "Today"
      assert html =~ "@#{login}"
      assert Accounts.get_user!(user.id).github_username == login
    end

    test "says when the linked GitHub user does not exist", %{conn: conn} do
      login = "ghost-#{System.unique_integer([:positive])}"
      seed_developer_stats(login, {:error, :not_found})

      {:ok, user} = Accounts.update_github_username(user_fixture(), %{"github_username" => login})
      conn = init_test_session(conn, user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/hub")
      assert render_async(view) =~ "was not found"
    end

    test "rejects an invalid username", %{conn: conn} do
      conn = init_test_session(conn, user_id: user_fixture().id)
      {:ok, view, _html} = live(conn, ~p"/hub")

      html =
        view
        |> form("#github-link-form", github: %{github_username: "not a login!"})
        |> render_submit()

      assert html =~ "is not a valid GitHub username"
    end
  end

  # Pre-fills Core.GitHub's 5-minute cache so the async developer card never
  # reaches the network in tests (keys are unique per test).
  defp seed_developer_stats(login, result) do
    :ets.insert(
      Core.GitHub.Cache.table(),
      {{:developer_stats, String.downcase(login)}, {System.system_time(:second), result}}
    )
  end

  describe "/welcome" do
    test "renders in the hub theme with the Profile & CV action", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/welcome")

      assert html =~ "hub-shell"
      assert html =~ "Enter Hub"
      assert html =~ "Profile &amp; CV"
    end

    test "shows the app version from mix.exs in the footer", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/welcome")

      assert html =~ "IziHub v#{Application.spec(:core, :vsn)}"
    end
  end

  defp user_fixture do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        email: "hub_live_user_#{unique}@example.com",
        password: "Password123!",
        username: "hub_live_user_#{unique}",
        full_name: "Hub Live User"
      })

    user
  end
end

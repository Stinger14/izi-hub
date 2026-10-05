defmodule CoreWeb.HubLiveTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.Accounts

  describe "/hub" do
    test "renders the dashboard widgets inside the hub theme", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/hub")

      assert html =~ "hub-shell"
      assert html =~ "Dashboard"
      assert html =~ "Your money, at a glance"
      assert html =~ "Creator stats"
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

    test "switches the stats card between creator and developer", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/hub")

      html = render_click(view, "set_stats_variant", %{"variant" => "developer"})
      assert html =~ "Developer stats"
      assert html =~ "Repositories"
      refute html =~ "Creator stats"

      html = render_click(view, "set_stats_variant", %{"variant" => "creator"})
      assert html =~ "Creator stats"
      assert html =~ "Video views"
    end

    test "ignores unknown stats variants", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/hub")

      html = render_click(view, "set_stats_variant", %{"variant" => "admin"})
      assert html =~ "Creator stats"
    end

    test "shows the GitHub details link only to signed-in users", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/hub")

      refute render_click(view, "set_stats_variant", %{"variant" => "developer"}) =~
               "GitHub details"

      conn = init_test_session(conn, user_id: user_fixture().id)
      {:ok, view, _html} = live(conn, ~p"/hub")

      assert render_click(view, "set_stats_variant", %{"variant" => "developer"}) =~
               "GitHub details"
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

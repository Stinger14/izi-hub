defmodule CoreWeb.Admin.AnalyticsLiveTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.Analytics

  test "renders analytics page for admins with recent visitor activity", %{conn: conn} do
    admin = admin_fixture()

    conn =
      conn
      |> init_test_session(user_id: admin.id)

    {:ok, _} =
      Analytics.record_page_view(%{
        page_path: "/cv/download",
        session_id: "session-a",
        country: "DO",
        city: "Santo Domingo",
        browser: "Chrome",
        os: "macOS",
        device_type: "desktop",
        referrer: "https://www.google.com/search?q=maxly"
      })

    assert {:ok, _view, html} = live(conn, ~p"/admin/analytics")

    assert html =~ "Analytics"
    assert html =~ "Recent visitor activity"
    assert html =~ "Guest "
    assert html =~ "/cv/download"
    assert html =~ "Santo Domingo, DO"
    assert html =~ "google.com"
  end
end

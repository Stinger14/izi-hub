defmodule CoreWeb.OfficeLiveTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.Accounts

  test "redirects unauthenticated users to login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/hub?auth=login"}}} = live(conn, ~p"/office")
  end

  test "renders the office workbench for authenticated users", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)

    assert {:ok, _view, html} = live(conn, ~p"/office")

    assert html =~ "IziOffice"
    assert html =~ "Personal roadmap"
    assert html =~ "Project roadmap"
    assert html =~ "Queue"
    assert html =~ "WIP"
    assert html =~ "QA"
    assert html =~ "Release"
    assert html =~ "Add entry"
    refute html =~ "Add roadmap entry"
  end

  test "creates queue tasks and advances them through the canvas flow", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)
    {:ok, view, _html} = live(conn, ~p"/office")

    expanded_html =
      view
      |> element("button[phx-click=\"open_entry_form\"]")
      |> render_click()

    assert expanded_html =~ "Add roadmap entry"

    create_params = %{
      "title" => "Ship Office live view",
      "description" => "Build the first workbench surface",
      "priority" => "high",
      "scheduled_for" => "",
      "due_at" => ""
    }

    html =
      view
      |> form("form[phx-submit=\"create_entry\"]", entry: create_params)
      |> render_submit()

    assert html =~ "Ship Office live view"
    assert html =~ "HIGH priority"

    html =
      view
      |> element("button[phx-value-to=\"wip\"]")
      |> render_click()

    assert html =~ "Send to QA"
    refute html =~ ">Start<"
  end

  test "creates milestone entries on the roadmap track", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)
    {:ok, view, _html} = live(conn, ~p"/office")

    view
    |> element("button[phx-click=\"open_entry_form\"]")
    |> render_click()

    milestone_html =
      view
      |> element("button[phx-value-kind=\"milestone\"]")
      |> render_click()

    assert milestone_html =~ "Milestone"

    html =
      view
      |> form("form[phx-submit=\"create_entry\"]",
        entry: %{
          "title" => "Launch checkpoint",
          "description" => "Internal milestone",
          "kind" => "milestone",
          "starts_at" => "2026-03-24T10:00",
          "ends_at" => ""
        }
      )
      |> render_submit()

    assert html =~ "Launch checkpoint"
    assert html =~ "Internal milestone"
  end

  test "opens project creator inline without hiding add entry", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)
    {:ok, view, _html} = live(conn, ~p"/office")

    html =
      view
      |> element("button[phx-click=\"open_project_form\"]")
      |> render_click()

    assert html =~ "Project title"
    assert html =~ "Add entry"
  end

  defp user_fixture do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        email: "office_live_user_#{unique}@example.com",
        password: "Password123!",
        username: "office_live_user_#{unique}",
        full_name: "Office Live User"
      })

    user
  end
end

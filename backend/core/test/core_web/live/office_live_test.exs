defmodule CoreWeb.OfficeLiveTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.Accounts
  alias Core.Office

  test "redirects unauthenticated users to login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/hub?auth=login"}}} = live(conn, ~p"/office")
  end

  test "renders the office workbench for authenticated users", %{conn: conn} do
    user = user_fixture()
    conn = init_test_session(conn, user_id: user.id)

    assert {:ok, _view, html} = live(conn, ~p"/office")

    assert html =~ "IziOffice"
    assert html =~ "Personal roadmap"
    assert html =~ "Roadmap"
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

  test "calendar filters roadmap rows by selected date and shows daily counts", %{conn: conn} do
    user = user_fixture()
    project = Office.default_project_for_user(user)
    selected_date = Date.utc_today() |> Date.add(2)
    other_date = Date.add(selected_date, 1)

    assert {:ok, work_item} =
             Office.create_work_item(user, project, %{
               "title" => "Plan sprint board",
               "description" => "Sync the stage board from the calendar sidebar",
               "scheduled_for" => Date.to_iso8601(selected_date)
             })

    assert {:ok, _entry} =
             Office.create_timeline_entry(user, project, %{
               "title" => "Planning review",
               "kind" => "milestone",
               "starts_at" => Date.to_iso8601(selected_date) <> "T10:00"
             })

    assert {:ok, _entry} =
             Office.create_timeline_entry(user, project, %{
               "title" => "Other day checkpoint",
               "kind" => "milestone",
               "starts_at" => Date.to_iso8601(other_date) <> "T11:00"
             })

    conn = init_test_session(conn, user_id: user.id)
    {:ok, view, html} = live(conn, ~p"/office")

    assert html =~ "Calendar"

    assert has_element?(
             view,
             "button[phx-click=\"select_calendar_date\"][phx-value-date=\"#{Date.to_iso8601(selected_date)}\"]"
           )

    html =
      view
      |> element(
        "button[phx-click=\"select_calendar_date\"][phx-value-date=\"#{Date.to_iso8601(selected_date)}\"]"
      )
      |> render_click()

    assert html =~ Calendar.strftime(selected_date, "%b %d, %Y")
    assert html =~ "Planning review"
    assert html =~ "Tasks for the day"
    assert html =~ "Plan sprint board"
    assert has_element?(view, "[data-roadmap-date=\"#{Date.to_iso8601(selected_date)}\"]")
    refute has_element?(view, "[data-roadmap-date=\"#{Date.to_iso8601(other_date)}\"]")

    html =
      view
      |> element(
        "button[phx-click=\"focus_day_task\"][phx-value-id=\"work-item:#{work_item.id}\"]"
      )
      |> render_click()

    assert html =~ "Sync the stage board from the calendar sidebar"
  end

  test "edits an existing roadmap event inline from the timeline popover", %{conn: conn} do
    user = user_fixture()
    project = Office.default_project_for_user(user)
    selected_date = Date.utc_today() |> Date.add(3)

    {:ok, entry} =
      Office.create_timeline_entry(user, project, %{
        "title" => "Design review",
        "description" => "Initial agenda",
        "kind" => "milestone",
        "starts_at" => Date.to_iso8601(selected_date) <> "T09:00"
      })

    conn = init_test_session(conn, user_id: user.id)
    {:ok, view, _html} = live(conn, ~p"/office")

    view
    |> element(
      "button[phx-click=\"select_calendar_date\"][phx-value-date=\"#{Date.to_iso8601(selected_date)}\"]"
    )
    |> render_click()

    view
    |> element("button[aria-label=\"Toggle #{entry.title}\"]")
    |> render_click()

    html =
      view
      |> element("button[phx-click=\"edit_timeline_entry\"][phx-value-id=\"#{entry.id}\"]")
      |> render_click()

    assert html =~ "Save changes"
    assert html =~ "Initial agenda"

    html =
      view
      |> form("form[phx-submit=\"save_timeline_entry\"]",
        entry: %{
          "title" => "Updated design review",
          "description" => "Refined agenda",
          "kind" => "deadline",
          "starts_at" => Date.to_iso8601(selected_date) <> "T10:30",
          "ends_at" => ""
        }
      )
      |> render_submit()

    assert html =~ "Updated design review"
    assert html =~ "Refined agenda"
    assert html =~ "Deadline"
    refute html =~ "Save changes"
  end

  test "closes a roadmap popover when clicking away", %{conn: conn} do
    user = user_fixture()
    project = Office.default_project_for_user(user)
    selected_date = Date.utc_today() |> Date.add(4)

    {:ok, entry} =
      Office.create_timeline_entry(user, project, %{
        "title" => "Team sync",
        "description" => "Review blockers and action items",
        "kind" => "milestone",
        "starts_at" => Date.to_iso8601(selected_date) <> "T11:00"
      })

    conn = init_test_session(conn, user_id: user.id)
    {:ok, view, _html} = live(conn, ~p"/office")

    view
    |> element(
      "button[phx-click=\"select_calendar_date\"][phx-value-date=\"#{Date.to_iso8601(selected_date)}\"]"
    )
    |> render_click()

    html =
      view
      |> element("button[aria-label=\"Toggle #{entry.title}\"]")
      |> render_click()

    assert html =~ "Review blockers and action items"

    assert has_element?(
             view,
             "button[phx-click=\"edit_timeline_entry\"][phx-value-id=\"#{entry.id}\"]"
           )

    _html = render_click(view, "close_roadmap_items", %{})

    refute has_element?(
             view,
             "button[phx-click=\"edit_timeline_entry\"][phx-value-id=\"#{entry.id}\"]"
           )
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

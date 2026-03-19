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
    assert html =~ ~s(data-stage-empty-state="queue")
    refute html =~ "No roadmap cards in Queue yet."
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
    assert has_element?(view, ~s([data-stage-canvas="queue"][style*="height: 18.0rem;"]))

    html =
      view
      |> element("button[phx-value-to=\"wip\"]")
      |> render_click()

    assert html =~ "Send to QA"
    refute html =~ ">Start<"
  end

  test "expands a stage task from the preview cta", %{conn: conn} do
    user = user_fixture()
    project = Office.default_project_for_user(user)

    {:ok, work_item} =
      Office.create_work_item(user, project, %{
        "title" => "Review launch copy",
        "description" => "Tighten the wording before handoff",
        "priority" => "medium"
      })

    conn = init_test_session(conn, user_id: user.id)
    {:ok, view, html} = live(conn, ~p"/office")

    refute html =~ ">Start<"

    html =
      view
      |> element("button[data-stage-open-id=\"work-item:#{work_item.id}\"]")
      |> render_click()

    assert html =~ "Tighten the wording before handoff"

    assert has_element?(
             view,
             "button[phx-click=\"transition_work_item\"][phx-value-id=\"#{work_item.id}\"][phx-value-to=\"wip\"]"
           )

    _html = render_click(view, "close_stage_items", %{})

    refute has_element?(
             view,
             "button[phx-click=\"transition_work_item\"][phx-value-id=\"#{work_item.id}\"][phx-value-to=\"wip\"]"
           )
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

  test "projects scheduled tasks onto the interactive roadmap", %{conn: conn} do
    user = user_fixture()
    project = Office.default_project_for_user(user)
    selected_date = Date.utc_today() |> Date.add(1)

    {:ok, work_item} =
      Office.create_work_item(user, project, %{
        "title" => "Prep release checklist",
        "description" => "Validate the launch tasks before shipping",
        "priority" => "high",
        "scheduled_for" => Date.to_iso8601(selected_date),
        "due_at" => Date.to_iso8601(selected_date) <> "T13:30"
      })

    conn = init_test_session(conn, user_id: user.id)
    {:ok, view, _html} = live(conn, ~p"/office")

    view
    |> element(
      "button[phx-click=\"select_calendar_date\"][phx-value-date=\"#{Date.to_iso8601(selected_date)}\"]"
    )
    |> render_click()

    assert has_element?(
             view,
             "[data-roadmap-date=\"#{Date.to_iso8601(selected_date)}\"] [data-roadmap-item-id=\"roadmap-work-item:#{work_item.id}\"]"
           )

    html =
      view
      |> element(
        "[data-roadmap-date=\"#{Date.to_iso8601(selected_date)}\"] [data-roadmap-item-id=\"roadmap-work-item:#{work_item.id}\"]"
      )
      |> render_click()

    assert html =~ "Queue task"
    assert html =~ "HIGH priority"
    assert html =~ "Open on board"
    refute html =~ ">Start<"

    html =
      view
      |> element("button[data-roadmap-open-board-id=\"#{work_item.id}\"]")
      |> render_click()

    assert html =~ "Validate the launch tasks before shipping"
    assert html =~ "Start"
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

  test "archives a non-default project from the current project card", %{conn: conn} do
    user = user_fixture()
    {:ok, project} = Office.create_project(user, %{"name" => "Client launch"})
    conn = init_test_session(conn, user_id: user.id)
    {:ok, view, _html} = live(conn, ~p"/office/#{project.slug}")

    html =
      view
      |> element("button[phx-click=\"archive_current_project\"]")
      |> render_click()

    assert html =~ "Personal roadmap"
    refute html =~ "Client launch</span></a>"
  end

  test "deletes a non-default project from the current project card", %{conn: conn} do
    user = user_fixture()
    {:ok, project} = Office.create_project(user, %{"name" => "Client launch"})
    _default_project = Office.default_project_for_user(user)

    assert {:ok, _work_item} =
             Office.create_work_item(user, project, %{"title" => "Ship launch"})

    assert {:ok, _entry} =
             Office.create_timeline_entry(user, project, %{
               "title" => "Launch review",
               "kind" => "milestone",
               "starts_at" => "2026-03-21T10:00"
             })

    conn = init_test_session(conn, user_id: user.id)
    {:ok, view, _html} = live(conn, ~p"/office/#{project.slug}")

    html =
      view
      |> element("button[phx-click=\"open_delete_project_confirm\"]")
      |> render_click()

    assert html =~ "Delete project"
    assert html =~ "1 tasks"
    assert html =~ "1 milestones"

    html =
      view
      |> element("button[phx-click=\"delete_current_project\"]")
      |> render_click()

    assert html =~ "Personal roadmap"
    refute html =~ "Client launch</span></a>"
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
        "button[phx-click=\"toggle_day_task_details\"][phx-value-id=\"work-item:#{work_item.id}\"]"
      )
      |> render_click()

    assert html =~ "Sync the stage board from the calendar sidebar"
    assert html =~ "Stage:"
  end

  test "selected day keeps an empty task card without helper copy when there are no tasks", %{
    conn: conn
  } do
    user = user_fixture()
    project = Office.default_project_for_user(user)
    selected_date = Date.utc_today() |> Date.add(4)

    assert {:ok, _entry} =
             Office.create_timeline_entry(user, project, %{
               "title" => "Design sync",
               "kind" => "milestone",
               "starts_at" => Date.to_iso8601(selected_date) <> "T10:00"
             })

    conn = init_test_session(conn, user_id: user.id)
    {:ok, view, _html} = live(conn, ~p"/office")

    html =
      view
      |> element(
        "button[phx-click=\"select_calendar_date\"][phx-value-date=\"#{Date.to_iso8601(selected_date)}\"]"
      )
      |> render_click()

    assert html =~ "Tasks for the day"
    refute html =~ "No tasks scheduled or due on this day."

    assert has_element?(view, "[data-selected-day-empty-state=\"tasks\"]")
  end

  test "selected day plus button opens an inline task form and creates a task", %{conn: conn} do
    user = user_fixture()
    project = Office.default_project_for_user(user)
    selected_date = Date.utc_today() |> Date.add(5)

    assert {:ok, _entry} =
             Office.create_timeline_entry(user, project, %{
               "title" => "Weekly review",
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

    assert has_element?(view, "[data-selected-day-add-entry=\"true\"]")

    html =
      view
      |> element("[data-selected-day-add-entry=\"true\"]")
      |> render_click()

    assert html =~ "Quick task"
    refute html =~ "Add roadmap entry"
    assert has_element?(view, "input#selected-day-entry-title")

    html =
      view
      |> form("form[phx-submit=\"create_selected_day_task\"]",
        selected_day_entry: %{
          "title" => "Draft launch note",
          "description" => "Capture the release summary",
          "priority" => "high",
          "due_at" => ""
        }
      )
      |> render_submit()

    assert html =~ "Draft launch note"
    assert has_element?(view, "[data-selected-day-add-entry=\"true\"]")
    refute has_element?(view, "input#selected-day-entry-title")
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

  test "expands a sidebar day task in place", %{conn: conn} do
    user = user_fixture()
    project = Office.default_project_for_user(user)
    selected_date = Date.utc_today() |> Date.add(5)

    {:ok, work_item} =
      Office.create_work_item(user, project, %{
        "title" => "Check release rollout",
        "description" => "Review the handoff notes with QA",
        "scheduled_for" => Date.to_iso8601(selected_date)
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
      |> element(
        "button[phx-click=\"toggle_day_task_details\"][phx-value-id=\"work-item:#{work_item.id}\"]"
      )
      |> render_click()

    assert html =~ "Review the handoff notes with QA"
    assert html =~ "Scheduled for"
    assert html =~ "Stage:"
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

defmodule CoreWeb.OfficeEditingTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.{Office, Repo}
  alias Core.Office.{Project, TimelineEntry, WorkItem}

  setup %{conn: conn} do
    user = user_fixture()
    project = Office.default_project_for_user(user)
    %{conn: log_in_user(conn, user), user: user, project: project}
  end

  defp open_task(view, task) do
    render_click(view, "toggle_canvas_item", %{"id" => "work-item:" <> task.id})
  end

  test "edits a task from its board card", %{conn: conn, user: user, project: project} do
    {:ok, task} = Office.create_work_item(user, project, %{"title" => "Draft spec"})
    {:ok, view, _html} = live(conn, ~p"/office")
    open_task(view, task)

    view |> element(~s(button[aria-label="Edit Draft spec"])) |> render_click()

    html =
      view
      |> form("#task-edit-#{task.id}",
        task_edit: %{title: "Final spec", priority: "high", scheduled_for: "2026-10-15"}
      )
      |> render_submit()

    assert html =~ "Task updated"
    updated = Repo.get!(WorkItem, task.id)
    assert updated.title == "Final spec"
    assert updated.priority == "high"
    assert updated.scheduled_for == ~D[2026-10-15]
  end

  test "deletes a task only after confirming", %{conn: conn, user: user, project: project} do
    {:ok, task} = Office.create_work_item(user, project, %{"title" => "Old idea"})
    {:ok, view, _html} = live(conn, ~p"/office")
    open_task(view, task)

    html = view |> element(~s(button[aria-label="Delete Old idea"])) |> render_click()
    assert html =~ "Delete this task?"
    assert Repo.get(WorkItem, task.id)

    html = view |> element("button[phx-click=delete_task]") |> render_click()
    assert html =~ "Task deleted"
    refute Repo.get(WorkItem, task.id)
  end

  test "deletes a milestone from its editor", %{conn: conn, user: user, project: project} do
    {:ok, entry} =
      Office.create_timeline_entry(user, project, %{
        "title" => "Kickoff",
        "kind" => "milestone",
        "starts_at" => Date.utc_today() |> Date.to_iso8601() |> Kernel.<>("T10:00")
      })

    {:ok, view, _html} = live(conn, ~p"/office")
    render_click(view, "edit_timeline_entry", %{"id" => entry.id})
    render_click(view, "request_entry_delete", %{})

    html = render_click(view, "delete_timeline_entry", %{})
    assert html =~ "Milestone deleted"
    refute Repo.get(TimelineEntry, entry.id)
  end

  test "renames the current project", %{conn: conn, project: project} do
    {:ok, view, _html} = live(conn, ~p"/office")
    view |> element(~s(button[aria-label="Rename project"])) |> render_click()

    html = view |> form("#project-rename-form", project: %{name: "My roadmap"}) |> render_submit()

    assert html =~ "Project renamed"
    assert Repo.get!(Project, project.id).name == "My roadmap"
  end

  describe "from the hub" do
    test "edits a task's title and day", %{conn: conn, user: user, project: project} do
      {:ok, task} = Office.create_work_item(user, project, %{"title" => "Call bank"})
      {:ok, view, _html} = live(conn, ~p"/hub")

      view |> element(~s(button[aria-label="Edit Call bank"])) |> render_click()

      view
      |> form("#hub-task-edit-#{task.id}",
        hub_task: %{title: "Call the bank", scheduled_for: "2026-10-14"}
      )
      |> render_submit()

      updated = Repo.get!(WorkItem, task.id)
      assert updated.title == "Call the bank"
      assert updated.scheduled_for == ~D[2026-10-14]
    end

    test "deletes after confirming, and an open board drops it live", %{
      conn: conn,
      user: user,
      project: project
    } do
      {:ok, task} = Office.create_work_item(user, project, %{"title" => "Throwaway"})
      {:ok, board, board_html} = live(conn, ~p"/office")
      assert board_html =~ "Throwaway"

      {:ok, hub, _html} = live(conn, ~p"/hub")
      html = hub |> element(~s(button[aria-label="Delete Throwaway"])) |> render_click()
      assert html =~ "Delete “Throwaway”?"

      hub |> element("button[phx-click=delete_hub_task]") |> render_click()
      refute Repo.get(WorkItem, task.id)
      refute render(board) =~ "Throwaway"
    end
  end
end

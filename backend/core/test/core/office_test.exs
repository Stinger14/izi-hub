defmodule Core.OfficeTest do
  use Core.DataCase, async: true

  alias Core.Accounts
  alias Core.Office
  alias Core.Office.WorkItemTransition
  alias Core.Repo

  test "default_project_for_user creates a bootstrap project" do
    user = user_fixture()

    project = Office.default_project_for_user(user)

    assert project.user_id == user.id
    assert project.slug == "personal-roadmap"
  end

  test "archive_project hides a non-default project from active listings" do
    user = user_fixture()
    _default_project = Office.default_project_for_user(user)
    {:ok, project} = Office.create_project(user, %{"name" => "Client launch"})

    assert {:ok, archived_project} = Office.archive_project(user, project)

    assert archived_project.status == "archived"
    refute Enum.any?(Office.list_projects_for_user(user), &(&1.id == project.id))
    assert Office.get_project_for_user(user, project.slug).slug == "personal-roadmap"
  end

  test "delete_project removes a non-default project and its data" do
    user = user_fixture()
    _default_project = Office.default_project_for_user(user)
    {:ok, project} = Office.create_project(user, %{"name" => "Client launch"})
    {:ok, work_item} = Office.create_work_item(user, project, %{"title" => "Ship launch"})

    {:ok, entry} =
      Office.create_timeline_entry(user, project, %{
        "title" => "Launch review",
        "kind" => "milestone",
        "starts_at" => "2026-03-20T10:30"
      })

    assert {:ok, _deleted_project} = Office.delete_project(user, project)
    refute Enum.any?(Office.list_projects_for_user(user), &(&1.id == project.id))

    assert_raise Ecto.NoResultsError, fn ->
      Office.get_work_item_for_project!(user.id, project.id, work_item.id)
    end

    assert_raise Ecto.NoResultsError, fn ->
      Office.get_timeline_entry_for_project!(user.id, project.id, entry.id)
    end
  end

  test "default project cannot be archived or deleted" do
    user = user_fixture()
    project = Office.default_project_for_user(user)

    assert {:error, :protected_default} = Office.archive_project(user, project)
    assert {:error, :protected_default} = Office.delete_project(user, project)
  end

  test "create_work_item always places new work in queue" do
    user = user_fixture()
    project = Office.default_project_for_user(user)

    assert {:ok, work_item} =
             Office.create_work_item(user, project, %{
               "title" => "Draft office schema",
               "priority" => "high"
             })

    assert work_item.user_id == user.id
    assert work_item.project_id == project.id
    assert work_item.status == "queue"
    assert work_item.sequence == 1
  end

  test "update_work_item edits an existing task without changing its lane" do
    user = user_fixture()
    project = Office.default_project_for_user(user)

    {:ok, work_item} =
      Office.create_work_item(user, project, %{
        "title" => "Draft office schema",
        "priority" => "low"
      })

    assert {:ok, updated_work_item} =
             Office.update_work_item(work_item, %{
               "title" => "Review office schema",
               "priority" => "high"
             })

    assert updated_work_item.title == "Review office schema"
    assert updated_work_item.priority == "high"
    assert updated_work_item.status == "queue"
  end

  test "transition_work_item records the status change" do
    user = user_fixture()
    project = Office.default_project_for_user(user)

    {:ok, work_item} =
      Office.create_work_item(user, project, %{"title" => "Move through the board"})

    assert {:ok, work_item} = Office.transition_work_item(work_item, "wip", user)
    assert work_item.status == "wip"

    transitions =
      WorkItemTransition
      |> where([transition], transition.work_item_id == ^work_item.id)
      |> Repo.all()

    assert length(transitions) == 1
    assert hd(transitions).from_status == "queue"
    assert hd(transitions).to_status == "wip"
  end

  test "transition_work_item rejects invalid stage jumps" do
    user = user_fixture()
    project = Office.default_project_for_user(user)
    {:ok, work_item} = Office.create_work_item(user, project, %{"title" => "Skip QA"})

    assert {:error, :invalid_transition} = Office.transition_work_item(work_item, "qa", user)
  end

  test "create_timeline_entry attaches milestones to the project" do
    user = user_fixture()
    project = Office.default_project_for_user(user)

    assert {:ok, entry} =
             Office.create_timeline_entry(user, project, %{
               "title" => "Beta launch",
               "description" => "Public milestone",
               "kind" => "milestone",
               "starts_at" => "2026-03-20T10:30"
             })

    assert entry.project_id == project.id
    assert entry.description == "Public milestone"
  end

  test "update_timeline_entry edits an existing roadmap event" do
    user = user_fixture()
    project = Office.default_project_for_user(user)

    {:ok, entry} =
      Office.create_timeline_entry(user, project, %{
        "title" => "Beta launch",
        "kind" => "milestone",
        "starts_at" => "2026-03-20T10:30"
      })

    assert {:ok, updated_entry} =
             Office.update_timeline_entry(entry, %{
               "title" => "Beta launch review",
               "description" => "Updated timeline note",
               "kind" => "deadline",
               "starts_at" => "2026-03-20T11:00"
             })

    assert updated_entry.title == "Beta launch review"
    assert updated_entry.description == "Updated timeline note"
    assert updated_entry.kind == "deadline"
  end

  describe "live updates" do
    test "successful writes broadcast on the user's topic" do
      user = user_fixture()
      project = Office.default_project_for_user(user)
      :ok = Office.subscribe(user)
      user_id = user.id

      {:ok, task} =
        elsewhere(fn -> Office.create_work_item(user, project, %{"title" => "Broadcast me"}) end)

      assert_receive {:office_changed, ^user_id}

      {:ok, _} = elsewhere(fn -> Office.transition_work_item(task, "wip", user) end)
      assert_receive {:office_changed, ^user_id}
    end

    test "the process that made the change does not get its own echo" do
      user = user_fixture()
      :ok = Office.subscribe(user)

      {:ok, _} =
        Office.create_work_item(user, Office.default_project_for_user(user), %{"title" => "Mine"})

      refute_receive {:office_changed, _}
    end

    test "failed writes do not broadcast" do
      user = user_fixture()
      project = Office.default_project_for_user(user)
      :ok = Office.subscribe(user)

      assert {:error, _} =
               elsewhere(fn -> Office.create_work_item(user, project, %{"title" => ""}) end)

      refute_receive {:office_changed, _}
    end

    test "other users' changes are not received" do
      me = user_fixture()
      other = user_fixture()
      :ok = Office.subscribe(me)

      {:ok, _} =
        Office.create_work_item(other, Office.default_project_for_user(other), %{
          "title" => "Theirs"
        })

      refute_receive {:office_changed, _}
    end
  end

  describe "cross-project views" do
    setup do
      user = user_fixture()
      default = Office.default_project_for_user(user)
      {:ok, side} = Office.create_project(user, %{"name" => "Side project"})
      %{user: user, default: default, side: side, today: ~D[2026-10-08]}
    end

    test "focus_tasks groups open tasks across projects by effective date", ctx do
      %{user: user, default: default, side: side, today: today} = ctx

      {:ok, _} =
        Office.create_work_item(user, default, %{
          "title" => "Late",
          "scheduled_for" => "2026-10-01"
        })

      {:ok, _} =
        Office.create_work_item(user, side, %{"title" => "Now", "scheduled_for" => "2026-10-08"})

      {:ok, _} =
        Office.create_work_item(user, default, %{
          "title" => "Due today",
          "scheduled_for" => "2026-10-02",
          "due_at" => "2026-10-08T17:00"
        })

      {:ok, _} =
        Office.create_work_item(user, side, %{"title" => "Later", "scheduled_for" => "2026-10-20"})

      {:ok, _} = Office.create_work_item(user, default, %{"title" => "Someday"})

      {:ok, done} =
        Office.create_work_item(user, default, %{
          "title" => "Shipped",
          "scheduled_for" => "2026-10-08"
        })

      done = release!(done, user)
      assert done.status == "release"

      focus = Office.focus_tasks(user, today)

      assert titles(focus.overdue) == ["Late"]
      assert Enum.sort(titles(focus.today)) == ["Due today", "Now"]
      assert titles(focus.up_next) == ["Later", "Someday"]
      assert focus.open_count == 5
      assert Enum.any?(focus.today, &(&1.task.project.name == "Side project"))
    end

    test "archived projects are excluded everywhere", %{user: user, side: side, today: today} do
      {:ok, _} =
        Office.create_work_item(user, side, %{
          "title" => "Hidden",
          "scheduled_for" => "2026-10-08"
        })

      {:ok, _} = Office.archive_project(user, side)

      assert Office.focus_tasks(user, today).open_count == 0
      assert Office.calendar_counts_for_user(user, ~D[2026-10-01], ~D[2026-10-31]) == %{}
      assert Office.agenda_for_day(user, today) == %{tasks: [], entries: []}
    end

    test "calendar counts and the day agenda agree", %{user: user, default: default, side: side} do
      {:ok, _} =
        Office.create_work_item(user, default, %{"title" => "A", "scheduled_for" => "2026-10-08"})

      {:ok, _} =
        Office.create_work_item(user, side, %{"title" => "B", "scheduled_for" => "2026-10-08"})

      {:ok, _} =
        Office.create_timeline_entry(user, side, %{
          "title" => "Review",
          "kind" => "deadline",
          "starts_at" => "2026-10-08T15:00"
        })

      counts = Office.calendar_counts_for_user(user, ~D[2026-10-01], ~D[2026-10-31])
      assert counts[~D[2026-10-08]] == %{task_count: 2, event_count: 1, total_count: 3}

      agenda = Office.agenda_for_day(user, ~D[2026-10-08])
      assert Enum.sort(Enum.map(agenda.tasks, & &1.title)) == ["A", "B"]
      assert Enum.map(agenda.entries, & &1.title) == ["Review"]
    end

    test "next_status follows the forward path" do
      assert Office.next_status("queue") == "wip"
      assert Office.next_status("wip") == "qa"
      assert Office.next_status("qa") == "release"
      assert Office.next_status("release") == nil
    end
  end

  # Run a write in another process, like a different LiveView would.
  defp elsewhere(fun), do: fun |> Task.async() |> Task.await()

  defp titles(group), do: Enum.map(group, & &1.task.title)

  defp release!(task, user) do
    Enum.reduce(["wip", "qa", "release"], task, fn status, acc ->
      {:ok, updated} = Office.transition_work_item(acc, status, user)
      updated
    end)
  end

  defp user_fixture do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        email: "office_user_#{unique}@example.com",
        password: "Password123!",
        username: "office_user_#{unique}",
        full_name: "Office User"
      })

    user
  end
end

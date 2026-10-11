defmodule Core.Office.EditingTest do
  use Core.DataCase, async: true

  alias Core.Office
  alias Core.Office.{Project, TimelineEntry, WorkItem, WorkItemTransition}

  setup do
    user = user_fixture()
    project = Office.default_project_for_user(user)
    %{user: user, project: project}
  end

  test "deletes a task with its transitions and unlinks its milestones", %{
    user: user,
    project: project
  } do
    {:ok, task} = Office.create_work_item(user, project, %{"title" => "Ship"})
    {:ok, _} = Office.transition_work_item(task, "wip", user)

    {:ok, entry} =
      Office.create_timeline_entry(user, project, %{
        "title" => "Launch",
        "kind" => "milestone",
        "starts_at" => "2026-10-20T10:00"
      })

    entry |> Ecto.Changeset.change(work_item_id: task.id) |> Repo.update!()

    assert {:ok, _} = Office.delete_work_item(user, task)
    refute Repo.get(WorkItem, task.id)
    assert Repo.all(from t in WorkItemTransition, where: t.work_item_id == ^task.id) == []
    assert %TimelineEntry{work_item_id: nil} = Repo.get!(TimelineEntry, entry.id)
  end

  test "only the owner can delete tasks and milestones", %{user: user, project: project} do
    other = user_fixture()
    {:ok, task} = Office.create_work_item(user, project, %{"title" => "Mine"})

    {:ok, entry} =
      Office.create_timeline_entry(user, project, %{
        "title" => "Mine",
        "kind" => "note",
        "starts_at" => "2026-10-20T10:00"
      })

    assert {:error, :forbidden} = Office.delete_work_item(other, task)
    assert {:error, :forbidden} = Office.delete_timeline_entry(other, entry)
    assert {:ok, _} = Office.delete_timeline_entry(user, entry)
    refute Repo.get(TimelineEntry, entry.id)
  end

  test "renames a project, keeping its slug; others can't", %{user: user} do
    {:ok, project} = Office.create_project(user, %{"name" => "Client launch"})

    assert {:ok, renamed} =
             Office.rename_project(user, project, %{
               "name" => "Client relaunch",
               "slug" => "hijack"
             })

    assert renamed.name == "Client relaunch"
    assert renamed.slug == project.slug

    assert {:error, :forbidden} =
             Office.rename_project(user_fixture(), project, %{"name" => "Theirs"})

    assert Repo.get!(Project, project.id).name == "Client relaunch"
  end

  test "deletes and renames broadcast to the owner's other pages", %{user: user, project: project} do
    {:ok, task} = Office.create_work_item(user, project, %{"title" => "Ship"})
    :ok = Office.subscribe(user)
    user_id = user.id

    {:ok, _} = Task.async(fn -> Office.delete_work_item(user, task) end) |> Task.await()
    assert_receive {:office_changed, ^user_id}

    {:ok, _} =
      Task.async(fn -> Office.rename_project(user, project, %{"name" => "Renamed"}) end)
      |> Task.await()

    assert_receive {:office_changed, ^user_id}
  end
end

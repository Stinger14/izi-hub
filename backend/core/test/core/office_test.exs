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

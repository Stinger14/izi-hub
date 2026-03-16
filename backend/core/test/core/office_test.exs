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

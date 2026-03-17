defmodule Core.Office do
  @moduledoc """
  The Office context for project-scoped roadmap planning.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Core.Accounts.User
  alias Core.Office.{CanvasLayout, Planner, Project, TimelineEntry, WorkItem, WorkItemTransition}
  alias Core.Repo

  @statuses WorkItem.statuses()

  def statuses, do: @statuses
  def canvas_stages, do: CanvasLayout.stages()

  def list_projects_for_user(%User{} = user) do
    _default_project = ensure_default_project(user)

    Project
    |> where([project], project.user_id == ^user.id)
    |> order_by([project], asc: project.inserted_at)
    |> Repo.all()
  end

  def default_project_for_user(%User{} = user) do
    ensure_default_project(user)
  end

  def get_project_for_user(%User{} = user, slug \\ nil) do
    default_project = ensure_default_project(user)

    case slug do
      nil ->
        default_project

      project_slug ->
        Repo.get_by(Project, user_id: user.id, slug: project_slug) || default_project
    end
  end

  def list_workbench_for_project(%Project{} = project) do
    work_items = list_work_items_for_project(project.id)
    timeline_entries = list_timeline_entries_for_project(project.id)

    %{
      project: project,
      work_items: work_items,
      timeline_entries: timeline_entries,
      canvas: CanvasLayout.layout(work_items, timeline_entries)
    }
  end

  def list_work_items_for_project(project_id) do
    WorkItem
    |> where([work_item], work_item.project_id == ^project_id)
    |> order_by([work_item], asc: work_item.sequence, asc: work_item.inserted_at)
    |> Repo.all()
  end

  def list_timeline_entries_for_project(project_id) do
    TimelineEntry
    |> where([entry], entry.project_id == ^project_id)
    |> order_by([entry], asc: entry.starts_at, asc: entry.inserted_at)
    |> Repo.all()
  end

  def create_project(%User{} = user, attrs) when is_map(attrs) do
    %Project{}
    |> Project.changeset(attrs)
    |> Ecto.Changeset.put_change(:user_id, user.id)
    |> Repo.insert()
  end

  def create_work_item(%User{} = user, %Project{} = project, attrs) when is_map(attrs) do
    attrs = Planner.normalize_quick_entry(attrs)

    %WorkItem{}
    |> WorkItem.planner_changeset(attrs)
    |> Ecto.Changeset.put_change(:status, "queue")
    |> Ecto.Changeset.put_change(:sequence, next_sequence(project.id, "queue"))
    |> Ecto.Changeset.put_change(:user_id, user.id)
    |> Ecto.Changeset.put_change(:project_id, project.id)
    |> Repo.insert()
  end

  def update_work_item(%WorkItem{} = work_item, attrs) when is_map(attrs) do
    attrs = Planner.normalize_quick_entry(attrs)

    work_item
    |> WorkItem.planner_changeset(attrs)
    |> Repo.update()
  end

  def transition_work_item(%WorkItem{} = work_item, to_status, %User{} = moved_by)
      when is_binary(to_status) do
    if WorkItem.valid_transition?(work_item.status, to_status) do
      Multi.new()
      |> Multi.update(
        :work_item,
        WorkItem.transition_changeset(work_item, %{
          status: to_status,
          sequence: next_sequence(work_item.project_id, to_status)
        })
      )
      |> Multi.insert(
        :transition,
        WorkItemTransition.create_changeset(
          %WorkItemTransition{},
          %{from_status: work_item.status, to_status: to_status},
          work_item.id,
          moved_by.id
        )
      )
      |> Repo.transaction()
      |> case do
        {:ok, %{work_item: updated_work_item}} -> {:ok, updated_work_item}
        {:error, _step, reason, _changes_so_far} -> {:error, reason}
      end
    else
      {:error, :invalid_transition}
    end
  end

  def create_timeline_entry(%User{} = user, %Project{} = project, attrs) when is_map(attrs) do
    attrs = Planner.normalize_timeline_entry(attrs)

    %TimelineEntry{}
    |> TimelineEntry.changeset(attrs)
    |> Ecto.Changeset.put_change(:user_id, user.id)
    |> Ecto.Changeset.put_change(:project_id, project.id)
    |> Repo.insert()
  end

  def update_timeline_entry(%TimelineEntry{} = timeline_entry, attrs) when is_map(attrs) do
    attrs = Planner.normalize_timeline_entry(attrs)

    timeline_entry
    |> TimelineEntry.changeset(attrs)
    |> Repo.update()
  end

  def get_work_item_for_project!(user_id, project_id, work_item_id) do
    WorkItem
    |> where(
      [work_item],
      work_item.user_id == ^user_id and work_item.project_id == ^project_id
    )
    |> Repo.get!(work_item_id)
  end

  def get_timeline_entry_for_project!(user_id, project_id, timeline_entry_id) do
    TimelineEntry
    |> where(
      [entry],
      entry.user_id == ^user_id and entry.project_id == ^project_id
    )
    |> Repo.get!(timeline_entry_id)
  end

  def planner_changeset(%WorkItem{} = work_item, attrs) when is_map(attrs) do
    WorkItem.planner_changeset(work_item, attrs)
  end

  def planner_changeset(attrs) when is_map(attrs) do
    WorkItem.planner_changeset(%WorkItem{}, attrs)
  end

  def timeline_entry_changeset(%TimelineEntry{} = timeline_entry, attrs) when is_map(attrs) do
    TimelineEntry.changeset(timeline_entry, attrs)
  end

  def timeline_entry_changeset(attrs) when is_map(attrs) do
    TimelineEntry.changeset(%TimelineEntry{}, attrs)
  end

  def project_changeset(attrs \\ %{}) do
    Project.changeset(%Project{}, attrs)
  end

  defp next_sequence(project_id, status) do
    WorkItem
    |> where([work_item], work_item.project_id == ^project_id and work_item.status == ^status)
    |> select([work_item], max(work_item.sequence))
    |> Repo.one()
    |> case do
      nil -> 1
      sequence -> sequence + 1
    end
  end

  defp ensure_default_project(%User{} = user) do
    project =
      Project
      |> where([project], project.user_id == ^user.id)
      |> order_by([project], asc: project.inserted_at)
      |> limit(1)
      |> Repo.one()
      |> case do
        nil ->
          case create_project(user, %{
                 "name" => "Personal roadmap",
                 "description" => "Default Office project for daily work and milestones."
               }) do
            {:ok, project} ->
              project

            {:error, _changeset} ->
              Project
              |> where([project], project.user_id == ^user.id)
              |> order_by([project], asc: project.inserted_at)
              |> limit(1)
              |> Repo.one!()
          end

        existing_project ->
          existing_project
      end

    backfill_legacy_records(user.id, project.id)
    project
  end

  defp backfill_legacy_records(user_id, project_id) do
    WorkItem
    |> where([work_item], work_item.user_id == ^user_id and is_nil(work_item.project_id))
    |> Repo.update_all(set: [project_id: project_id])

    TimelineEntry
    |> where([entry], entry.user_id == ^user_id and is_nil(entry.project_id))
    |> Repo.update_all(set: [project_id: project_id])
  end
end

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

  # ------ Live updates ------
  #
  # Every successful write below broadcasts {:office_changed, user_id} on a
  # per-user topic, so any LiveView showing that user's Office data (the
  # IziOffice page, the hub's Tasks panel and calendar, a second tab) can
  # reload. Subscribe from a LiveView's connected mount.

  @pubsub Core.PubSub

  def subscribe(%User{id: user_id}), do: Phoenix.PubSub.subscribe(@pubsub, topic(user_id))

  defp topic(user_id), do: "office:user:#{user_id}"

  defp broadcast_change({:ok, _} = result, user_id) do
    # broadcast_from skips the calling process: the LiveView that made the
    # change already refreshes itself, so it doesn't need its own echo.
    Phoenix.PubSub.broadcast_from(@pubsub, self(), topic(user_id), {:office_changed, user_id})
    result
  end

  defp broadcast_change(result, _user_id), do: result

  def list_projects_for_user(%User{} = user) do
    _default_project = ensure_default_project(user)

    Project
    |> where([project], project.user_id == ^user.id and project.status == "active")
    |> order_by([project], asc: project.inserted_at)
    |> Repo.all()
  end

  def default_project_for_user(%User{} = user) do
    ensure_default_project(user)
  end

  def project_summary(%Project{} = project) do
    work_item_count =
      WorkItem
      |> where([work_item], work_item.project_id == ^project.id)
      |> select([work_item], count(work_item.id))
      |> Repo.one()

    timeline_entry_count =
      TimelineEntry
      |> where([entry], entry.project_id == ^project.id)
      |> select([entry], count(entry.id))
      |> Repo.one()

    transition_count =
      WorkItemTransition
      |> join(:inner, [transition], work_item in WorkItem,
        on: transition.work_item_id == work_item.id
      )
      |> where([_transition, work_item], work_item.project_id == ^project.id)
      |> select([transition, _work_item], count(transition.id))
      |> Repo.one()

    %{
      work_item_count: work_item_count || 0,
      timeline_entry_count: timeline_entry_count || 0,
      transition_count: transition_count || 0
    }
  end

  def archive_project(%User{} = user, %Project{} = project) do
    result =
      with :ok <- ensure_project_owner(user, project),
           :ok <- ensure_not_default_project(user, project) do
        project
        |> Project.changeset(%{"status" => "archived"})
        |> Repo.update()
      end

    broadcast_change(result, user.id)
  end

  def delete_project(%User{} = user, %Project{} = project) do
    result =
      with :ok <- ensure_project_owner(user, project),
           :ok <- ensure_not_default_project(user, project) do
        Repo.delete(project)
      end

    broadcast_change(result, user.id)
  end

  def default_project?(%User{} = user, %Project{} = project) do
    ensure_default_project(user).id == project.id
  end

  def active_project?(%Project{} = project), do: project.status == "active"

  def get_project_for_user(%User{} = user, slug \\ nil) do
    default_project = ensure_default_project(user)

    case slug do
      nil ->
        default_project

      project_slug ->
        Project
        |> where(
          [project],
          project.user_id == ^user.id and project.slug == ^project_slug and
            project.status == "active"
        )
        |> Repo.one() || default_project
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
    |> broadcast_change(user.id)
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
    |> broadcast_change(user.id)
  end

  def update_work_item(%WorkItem{} = work_item, attrs) when is_map(attrs) do
    attrs = Planner.normalize_quick_entry(attrs)

    work_item
    |> WorkItem.planner_changeset(attrs)
    |> Repo.update()
    |> broadcast_change(work_item.user_id)
  end

  def transition_work_item(%WorkItem{} = work_item, to_status, %User{} = moved_by)
      when is_binary(to_status) do
    result =
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

    broadcast_change(result, work_item.user_id)
  end

  def create_timeline_entry(%User{} = user, %Project{} = project, attrs) when is_map(attrs) do
    attrs = Planner.normalize_timeline_entry(attrs)

    %TimelineEntry{}
    |> TimelineEntry.changeset(attrs)
    |> Ecto.Changeset.put_change(:user_id, user.id)
    |> Ecto.Changeset.put_change(:project_id, project.id)
    |> Repo.insert()
    |> broadcast_change(user.id)
  end

  def update_timeline_entry(%TimelineEntry{} = timeline_entry, attrs) when is_map(attrs) do
    attrs = Planner.normalize_timeline_entry(attrs)

    timeline_entry
    |> TimelineEntry.changeset(attrs)
    |> Repo.update()
    |> broadcast_change(timeline_entry.user_id)
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

  # ------ Calendar & cross-project views ------
  #
  # Shared by OfficeLive (one project) and HubLive (all active projects) so a
  # day's count can never differ between the two.

  @open_statuses ["queue", "wip", "qa"]

  @doc """
  Per-day counts for the calendar dots: a task counts on its scheduled day and
  on its due day; a timeline entry counts on the day it starts.
  """
  def calendar_counts(work_items, timeline_entries) do
    work_items
    |> Enum.reduce(%{}, fn work_item, acc ->
      acc
      |> track_calendar_item(:tasks, work_item.id, work_item.scheduled_for)
      |> track_calendar_item(:tasks, work_item.id, to_date(work_item.due_at))
    end)
    |> then(fn acc ->
      Enum.reduce(timeline_entries, acc, fn entry, inner ->
        track_calendar_item(inner, :events, entry.id, to_date(entry.starts_at))
      end)
    end)
    |> Map.new(fn {date, %{tasks: tasks, events: events}} ->
      task_count = MapSet.size(tasks)
      event_count = MapSet.size(events)

      {date,
       %{task_count: task_count, event_count: event_count, total_count: task_count + event_count}}
    end)
  end

  @doc "Calendar counts across all of the user's active projects for a date range."
  def calendar_counts_for_user(%User{} = user, %Date{} = first_day, %Date{} = last_day) do
    first = NaiveDateTime.new!(first_day, ~T[00:00:00])
    last = NaiveDateTime.new!(last_day, ~T[23:59:59])

    work_items =
      user
      |> active_work_items_query()
      |> where(
        [work_item],
        (work_item.scheduled_for >= ^first_day and work_item.scheduled_for <= ^last_day) or
          (work_item.due_at >= ^first and work_item.due_at <= ^last)
      )
      |> Repo.all()

    timeline_entries =
      user
      |> active_timeline_entries_query()
      |> where([entry], entry.starts_at >= ^first and entry.starts_at <= ^last)
      |> Repo.all()

    calendar_counts(work_items, timeline_entries)
  end

  @doc """
  Open tasks (queue/wip/qa) across active projects for the hub's focus list,
  grouped by their effective date (due date, else scheduled date):
  `%{overdue: [...], today: [...], up_next: [...], open_count: n}`. Each group
  is ordered by date (undated last), and the three groups share `limit`.
  """
  def focus_tasks(%User{} = user, %Date{} = today, opts \\ []) do
    limit = Keyword.get(opts, :limit, 6)

    tasks =
      user
      |> active_work_items_query()
      |> where([work_item], work_item.status in @open_statuses)
      |> preload(:project)
      |> Repo.all()
      |> Enum.map(&{&1, effective_date(&1)})
      |> Enum.sort_by(fn {task, date} ->
        {is_nil(date), date && Date.to_gregorian_days(date), task.sequence}
      end)

    shown = Enum.take(tasks, limit)

    groups =
      Enum.group_by(
        shown,
        fn
          {_task, nil} ->
            :up_next

          {_task, date} ->
            case Date.compare(date, today) do
              :lt -> :overdue
              :eq -> :today
              :gt -> :up_next
            end
        end,
        fn {task, date} -> %{task: task, date: date} end
      )

    %{
      overdue: Map.get(groups, :overdue, []),
      today: Map.get(groups, :today, []),
      up_next: Map.get(groups, :up_next, []),
      open_count: length(tasks)
    }
  end

  @doc "A day's tasks and timeline entries across the user's active projects."
  def agenda_for_day(%User{} = user, %Date{} = date) do
    first = NaiveDateTime.new!(date, ~T[00:00:00])
    last = NaiveDateTime.new!(date, ~T[23:59:59])

    tasks =
      user
      |> active_work_items_query()
      |> where(
        [work_item],
        work_item.scheduled_for == ^date or
          (work_item.due_at >= ^first and work_item.due_at <= ^last)
      )
      |> order_by([work_item], asc: work_item.sequence)
      |> preload(:project)
      |> Repo.all()

    entries =
      user
      |> active_timeline_entries_query()
      |> where([entry], entry.starts_at >= ^first and entry.starts_at <= ^last)
      |> order_by([entry], asc: entry.starts_at)
      |> preload(:project)
      |> Repo.all()

    %{tasks: tasks, entries: entries}
  end

  def open_status?(status), do: status in @open_statuses

  @doc "The next forward stage for a task, or nil once released."
  def next_status("queue"), do: "wip"
  def next_status("wip"), do: "qa"
  def next_status("qa"), do: "release"
  def next_status(_status), do: nil

  @doc "Fetches one of the user's work items in an active project, or nil."
  def get_user_work_item(%User{} = user, id) do
    user |> active_work_items_query() |> where([work_item], work_item.id == ^id) |> Repo.one()
  end

  defp active_work_items_query(%User{id: user_id}) do
    WorkItem
    |> join(:inner, [work_item], project in Project, on: project.id == work_item.project_id)
    |> where([work_item, project], work_item.user_id == ^user_id and project.status == "active")
  end

  defp active_timeline_entries_query(%User{id: user_id}) do
    TimelineEntry
    |> join(:inner, [entry], project in Project, on: project.id == entry.project_id)
    |> where([entry, project], entry.user_id == ^user_id and project.status == "active")
  end

  defp effective_date(%WorkItem{due_at: %NaiveDateTime{} = due_at}),
    do: NaiveDateTime.to_date(due_at)

  defp effective_date(%WorkItem{scheduled_for: scheduled_for}), do: scheduled_for

  defp to_date(nil), do: nil
  defp to_date(%NaiveDateTime{} = datetime), do: NaiveDateTime.to_date(datetime)

  defp track_calendar_item(acc, _kind, _id, nil), do: acc

  defp track_calendar_item(acc, kind, id, %Date{} = date) do
    acc
    |> Map.put_new(date, %{tasks: MapSet.new(), events: MapSet.new()})
    |> update_in([date, kind], &MapSet.put(&1, id))
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
      |> where([project], project.user_id == ^user.id and project.slug == "personal-roadmap")
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
              |> where(
                [project],
                project.user_id == ^user.id and project.slug == "personal-roadmap"
              )
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

  defp ensure_project_owner(%User{} = user, %Project{} = project) do
    if project.user_id == user.id, do: :ok, else: {:error, :forbidden}
  end

  defp ensure_not_default_project(%User{} = user, %Project{} = project) do
    if default_project?(user, project), do: {:error, :protected_default}, else: :ok
  end
end

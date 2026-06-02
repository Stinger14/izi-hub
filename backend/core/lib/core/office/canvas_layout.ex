defmodule Core.Office.CanvasLayout do
  @moduledoc """
  Builds deterministic canvas slots for Office projects.
  """

  alias Core.Office.WorkItem

  @stages WorkItem.statuses()

  def stages, do: @stages

  def layout(work_items, timeline_entries) do
    %{
      milestones: milestone_items(timeline_entries),
      stage_items: stage_items_by_stage(work_items)
    }
  end

  defp stage_items_by_stage(work_items) do
    Enum.into(@stages, %{}, fn stage ->
      items =
        work_items
        |> Enum.filter(&(&1.status == stage))
        |> Enum.sort_by(&sort_task_key/1)
        |> Enum.with_index()
        |> Enum.map(fn {work_item, slot_index} ->
          %{
            id: "work-item:" <> work_item.id,
            item_type: :task,
            stage: stage,
            slot_index: slot_index,
            title: work_item.title,
            description: work_item.description,
            status: work_item.status,
            priority: work_item.priority,
            scheduled_for: work_item.scheduled_for,
            due_at: work_item.due_at,
            sequence: work_item.sequence,
            record_id: work_item.id
          }
        end)

      {stage, items}
    end)
  end

  defp milestone_items(timeline_entries) do
    timeline_entries
    |> Enum.sort_by(&sort_timeline_key/1)
    |> Enum.with_index()
    |> Enum.map(fn {entry, slot_index} ->
      %{
        id: "timeline-entry:" <> entry.id,
        item_type: :milestone,
        slot_index: slot_index,
        track_index: rem(slot_index, 2),
        title: entry.title,
        description: entry.description,
        kind: entry.kind,
        starts_at: entry.starts_at,
        ends_at: entry.ends_at,
        record_id: entry.id
      }
    end)
  end

  defp sort_task_key(work_item) do
    {work_item.sequence, schedule_key(work_item), NaiveDateTime.to_erl(work_item.inserted_at)}
  end

  defp schedule_key(work_item) do
    cond do
      is_struct(work_item.due_at, NaiveDateTime) -> {0, NaiveDateTime.to_erl(work_item.due_at)}
      is_struct(work_item.scheduled_for, Date) -> {1, Date.to_erl(work_item.scheduled_for)}
      true -> {2, NaiveDateTime.to_erl(work_item.inserted_at)}
    end
  end

  defp sort_timeline_key(entry) do
    {NaiveDateTime.to_erl(entry.starts_at), NaiveDateTime.to_erl(entry.inserted_at), entry.title}
  end
end

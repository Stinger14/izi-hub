defmodule Core.Office.Planner do
  @moduledoc """
  Cleans form input before tasks and timeline entries are saved.

  Context: `Core.Office` runs every create/update through it: string keys,
  trimmed values, and only the fields a form may set.

  ## Example

      Planner.normalize_quick_entry(%{title: "  Ship  ", status: "release"})
      #=> %{"title" => "Ship"}
  """

  @doc """
  Keeps a task's editable fields (title, description, priority, scheduled, due),
  normalised.
  """
  def normalize_quick_entry(attrs) when is_map(attrs) do
    attrs
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      Map.put(acc, to_string(key), normalize_value(value))
    end)
    |> Map.take(["title", "description", "priority", "scheduled_for", "due_at"])
  end

  @doc "Keeps a timeline entry's editable fields (title, description, kind, dates), normalised."
  def normalize_timeline_entry(attrs) when is_map(attrs) do
    attrs
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      Map.put(acc, to_string(key), normalize_value(value))
    end)
    |> Map.take(["title", "description", "kind", "starts_at", "ends_at"])
  end

  defp normalize_value(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_value(value), do: value
end

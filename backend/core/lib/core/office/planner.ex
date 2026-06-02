defmodule Core.Office.Planner do
  @moduledoc """
  Helpers for fast work item capture from the Office planner.
  """

  def normalize_quick_entry(attrs) when is_map(attrs) do
    attrs
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      Map.put(acc, to_string(key), normalize_value(value))
    end)
    |> Map.take(["title", "description", "priority", "scheduled_for", "due_at"])
  end

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

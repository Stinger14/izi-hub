defmodule Core.Office.TimelineLayout do
  @moduledoc """
  Computes stable overlap lanes for timeline entries.
  """

  def layout(entries) when is_list(entries) do
    entries
    |> Enum.sort_by(&sort_key/1)
    |> Enum.reduce({[], []}, fn entry, {laid_out_entries, lane_ends} ->
      lane_index = find_available_lane(lane_ends, entry)
      lane_ends = update_lane_ends(lane_ends, lane_index, entry_end_at(entry))

      laid_out_entry =
        entry
        |> Map.put(:lane_index, lane_index)
        |> Map.put(:lane_count, length(lane_ends))

      {[laid_out_entry | laid_out_entries], lane_ends}
    end)
    |> then(fn {laid_out_entries, lane_ends} ->
      lane_count = max(length(lane_ends), 1)

      laid_out_entries
      |> Enum.reverse()
      |> Enum.map(&Map.put(&1, :lane_count, lane_count))
    end)
  end

  defp sort_key(entry) do
    {entry.starts_at, entry_end_at(entry), Map.get(entry, :title, "")}
  end

  defp find_available_lane(lane_ends, entry) do
    Enum.find_index(lane_ends, fn lane_end ->
      NaiveDateTime.compare(entry.starts_at, lane_end) != :lt
    end) || length(lane_ends)
  end

  defp update_lane_ends(lane_ends, lane_index, end_at) do
    case Enum.split(lane_ends, lane_index) do
      {left, [_existing | right]} -> left ++ [end_at] ++ right
      {left, []} -> left ++ [end_at]
    end
  end

  defp entry_end_at(entry) do
    Map.get(entry, :ends_at) || entry.starts_at
  end
end

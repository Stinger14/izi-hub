defmodule Core.HackerNews do
  @moduledoc false

  @base_api "https://hacker-news.firebaseio.com/v0"
  @cache_table Core.HackerNews.Cache
  @cache_ttl_seconds 300
  @default_limit 10
  @default_recent_seconds 86_400

  def fetch_best_stories(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    recent_seconds = Keyword.get(opts, :within_seconds, @default_recent_seconds)

    fetch_cache({:best, limit, recent_seconds}, fn ->
      with {:ok, ids} when is_list(ids) <- request("#{@base_api}/beststories.json") do
        items =
          ids
          |> Enum.take(80)
          |> fetch_items()

        recent =
          items
          |> Enum.filter(&recent?(&1, recent_seconds))

        if recent == [] do
          Enum.take(items, limit)
        else
          Enum.take(recent, limit)
        end
      else
        _ -> []
      end
    end)
  end

  defp fetch_items(ids) do
    ids
    |> Task.async_stream(&fetch_item/1, timeout: :infinity, max_concurrency: 10)
    |> Enum.reduce([], fn
      {:ok, item}, acc when is_map(item) -> [item | acc]
      _, acc -> acc
    end)
    |> Enum.reverse()
  end

  defp fetch_item(id) do
    url = "#{@base_api}/item/#{id}.json"

    case request(url) do
      {:ok, %{"type" => "story"} = item} -> format_item(item)
      _ -> nil
    end
  end

  defp format_item(item) do
    time = item["time"] || 0
    id = item["id"]

    %{
      id: id,
      title: item["title"] || "Untitled",
      score: item["score"] || 0,
      comments: item["descendants"] || 0,
      author: item["by"] || "unknown",
      time: time,
      age: humanize_age(time),
      url: item["url"] || hn_item_url(id),
      hn_url: hn_item_url(id)
    }
  end

  defp hn_item_url(id), do: "https://news.ycombinator.com/item?id=#{id}"

  defp humanize_age(time) when is_integer(time) do
    now = System.system_time(:second)
    diff = max(now - time, 0)

    cond do
      diff < 60 -> "#{diff}s ago"
      diff < 3_600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3_600)}h ago"
      true -> "#{div(diff, 86_400)}d ago"
    end
  end

  defp humanize_age(_), do: "unknown"

  defp recent?(%{time: time}, within_seconds) when is_integer(time) do
    now = System.system_time(:second)
    now - time <= within_seconds
  end

  defp recent?(_, _), do: false

  defp request(url) do
    url
    |> Req.get(headers: [{"user-agent", "izi-hub"}])
    |> case do
      {:ok, %{status: 200, body: body}} -> {:ok, normalize_body(body)}
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      _ -> body
    end
  end

  defp normalize_body(body), do: body

  defp fetch_cache(key, fun) do
    now = System.system_time(:second)
    table = @cache_table.table()

    case :ets.lookup(table, key) do
      [{^key, {cached_at, value}}] when now - cached_at < @cache_ttl_seconds ->
        value

      _ ->
        value = fun.()
        :ets.insert(table, {key, {now, value}})
        value
    end
  end
end

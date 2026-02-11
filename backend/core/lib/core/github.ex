defmodule Core.GitHub do
  @moduledoc false

  @base_api "https://api.github.com"
  @base_site "https://github.com"
  @cache_table Core.GitHub.Cache
  @cache_ttl_seconds 300
  @users ["Stinger14", "ghost1ndshell"]

  def fetch_accounts do
    Enum.map(@users, &fetch_account/1)
  end

  defp fetch_account(username) do
    %{
      username: username,
      repo_url: "#{@base_site}/#{username}",
      contributions_svg: fetch_contributions_svg(username),
      events: fetch_events(username)
    }
  end

  defp fetch_events(username) do
    fetch_cache({:events, username}, fn ->
      url = "#{@base_api}/users/#{username}/events/public"

      case request(url) do
        {:ok, events} when is_list(events) ->
          events
          |> Enum.take(5)
          |> Enum.map(&format_event/1)

        _ ->
          []
      end
    end)
  end

  defp fetch_contributions_svg(username) do
    fetch_cache({:contribs, username}, fn ->
      url = "#{@base_site}/users/#{username}/contributions"

      case request_raw(url, [{"accept", "image/svg+xml"}]) do
        {:ok, svg} -> sanitize_svg(svg)
        _ -> nil
      end
    end)
  end

  defp format_event(event) do
    %{
      id: event["id"],
      type: event_type(event["type"]),
      repo: get_in(event, ["repo", "name"]) || "unknown",
      repo_url: repo_url(event),
      created_at: format_timestamp(event["created_at"])
    }
  end

  defp event_type(nil), do: "Activity"

  defp event_type(type) do
    type
    |> String.replace_suffix("Event", "")
    |> String.replace("_", " ")
  end

  defp repo_url(event) do
    case get_in(event, ["repo", "name"]) do
      nil -> @base_site
      repo -> "#{@base_site}/#{repo}"
    end
  end

  defp format_timestamp(nil), do: "unknown time"

  defp format_timestamp(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, datetime, _offset} ->
        Calendar.strftime(datetime, "%b %d, %Y")

      _ ->
        timestamp
    end
  end

  defp request(url) do
    url
    |> Req.get(headers: github_headers())
    |> case do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp request_raw(url, extra_headers) do
    url
    |> Req.get(headers: github_headers() ++ extra_headers)
    |> case do
      {:ok, %{status: 200, body: body}} when is_binary(body) -> {:ok, body}
      {:ok, %{status: 200, body: body}} -> {:ok, to_string(body)}
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp github_headers do
    headers = [{"user-agent", "izi-hub"}]

    case github_token() do
      token when is_binary(token) and token != "" ->
        [{"authorization", "Bearer #{token}"} | headers]

      _ ->
        headers
    end
  end

  defp github_token do
    case Core.Config.github_token() do
      {:ok, token} when is_binary(token) -> String.trim(token)
      _ -> ""
    end
  end

  defp sanitize_svg(svg) when is_binary(svg) do
    with {:ok, document} <- Floki.parse_document(svg),
         [svg_node | _] <- Floki.find(document, "svg") do
      [svg_node]
      |> Floki.filter_out("script, foreignObject")
      |> Floki.traverse_and_update(&sanitize_node/1)
      |> Floki.raw_html()
    else
      _ -> nil
    end
  end

  defp sanitize_node({tag, attrs, children}) do
    if allowed_tag?(tag) do
      {tag, sanitize_attrs(attrs), children}
    else
      ""
    end
  end

  defp sanitize_node(other), do: other

  defp allowed_tag?(tag) do
    tag in [
      "svg",
      "g",
      "rect",
      "path",
      "text",
      "title",
      "desc",
      "defs",
      "style",
      "clipPath",
      "linearGradient",
      "stop"
    ]
  end

  defp sanitize_attrs(attrs) do
    Enum.filter(attrs, fn {name, value} ->
      allowed_attr?(name) and safe_value?(value)
    end)
  end

  defp allowed_attr?(name) do
    name in [
      "class",
      "id",
      "width",
      "height",
      "x",
      "y",
      "rx",
      "ry",
      "d",
      "fill",
      "stroke",
      "stroke-width",
      "stroke-linecap",
      "stroke-linejoin",
      "transform",
      "viewBox",
      "xmlns",
      "xmlns:xlink",
      "xlink:href",
      "aria-label",
      "role",
      "font-size",
      "text-anchor"
    ] or String.starts_with?(name, "data-") or String.starts_with?(name, "aria-")
  end

  defp safe_value?(value) when is_binary(value) do
    value_downcase = String.downcase(value)
    not String.contains?(value_downcase, "javascript:")
  end

  defp safe_value?(_), do: true

  defp fetch_cache(key, fun) do
    now = System.system_time(:second)

    case :ets.lookup(@cache_table.table(), key) do
      [{^key, {cached_at, value}}] when now - cached_at < @cache_ttl_seconds ->
        value

      _ ->
        value = fun.()
        :ets.insert(@cache_table.table(), {key, {now, value}})
        value
    end
  end
end

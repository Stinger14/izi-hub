defmodule Core.GitHub do
  @moduledoc false
  require Logger

  @base_api "https://api.github.com"
  @graphql_url "https://api.github.com/graphql"
  @base_site "https://github.com"
  @cache_table Core.GitHub.Cache
  @cache_ttl_seconds 300
  @users ["Stinger14", "ghost1ndshell"]
  @calendar_query """
  query($login: String!) {
   user(login: $login) {
      contributionsCollection {
        contributionCalendar {
          totalContributions
          weeks {
            contributionDays { date contributionCount contributionLevel weekday }
          }
        }
      }
    }
  }
  """

  def fetch_accounts do
    Enum.map(@users, &fetch_account/1)
  end

  def build_activity_feed(accounts) when is_list(accounts) do
    accounts
    |> Enum.flat_map(fn account ->
      Enum.map(account.events, fn event ->
        event
        |> Map.put(:account_username, account.username)
        |> Map.put(:sort_key, sort_key(event))
      end)
    end)
    |> Enum.sort(&activity_before?/2)
  end

  def activity_summary(accounts) when is_list(accounts) do
    feed = build_activity_feed(accounts)
    commits = Enum.flat_map(feed, & &1.commits)

    %{
      commits_count: length(commits),
      repos_touched: feed |> Enum.map(& &1.repo) |> Enum.uniq() |> length(),
      open_source_repos:
        feed
        |> Enum.filter(&(&1.category == :open_source))
        |> Enum.map(& &1.repo)
        |> Enum.uniq()
        |> length(),
      last_activity_at:
        case feed do
          [latest | _] -> latest.created_at_label
          [] -> "No recent activity"
        end
    }
  end

  @doc false
  def parse_contribution_calendar(%{"errors" => errors}), do: {:error, {:graphql, errors}}

  def parse_contribution_calendar(%{
        "data" => %{"user" => %{"contributionsCollection" => %{"contributionCalendar" => cal}}}
      }) do
    weeks =
      Enum.map(cal["weeks"], fn %{"contributionDays" => days} ->
        Enum.map(days, fn day ->
          %{
            date: Date.from_iso8601!(day["date"]),
            count: day["contributionCount"],
            level: contribution_level(day["contributionLevel"]),
            weekday: day["weekday"]
          }
        end)
      end)

    {:ok, %{total: cal["totalContributions"], weeks: weeks}}
  end

  def parse_contribution_calendar(%{"data" => %{"user" => nil}}), do: {:error, :user_not_found}
  def parse_contribution_calendar(_other), do: {:error, :unexpected_shape}

  defp contribution_level("NONE"), do: 0
  defp contribution_level("FIRST_QUARTILE"), do: 1
  defp contribution_level("SECOND_QUARTILE"), do: 2
  defp contribution_level("THIRD_QUARTILE"), do: 3
  defp contribution_level("FOURTH_QUARTILE"), do: 4
  defp contribution_level(_), do: 0

  defp fetch_account(username) do
    %{
      username: username,
      repo_url: "#{@base_site}/#{username}",
      contributions: fetch_contribution_calendar(username),
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

  defp fetch_contribution_calendar(username) do
    fetch_cache({:contributions, username}, fn ->
      case github_token() do
        "" ->
          Logger.warning("GitHub contribution calendar skipped: no GITHUB_TOKEN configured")
          nil

        _token ->
          @graphql_url
          |> Req.post(
            headers: github_headers(),
            json: %{query: @calendar_query, variables: %{login: username}}
          )
          |> case do
            {:ok, %{status: 200, body: body}} ->
              case parse_contribution_calendar(body) do
                {:ok, calendar} ->
                  calendar

                {:error, reason} ->
                  Logger.warning(
                    "GitHub contribution calendar for #{username} failed: #{inspect(reason)}"
                  )

                  nil
              end

            {:ok, %{status: status, body: body}} ->
              message = if is_map(body), do: body["message"]

              Logger.warning(
                "GitHub contribution calendar for #{username} returned HTTP #{status}" <>
                  if(message, do: ": #{message}", else: "")
              )

              nil

            {:error, reason} ->
              Logger.warning(
                "GitHub contribution calendar for #{username} errored: #{inspect(reason)}"
              )

              nil
          end
      end
    end)
  end

  defp format_event(event) do
    repo = get_in(event, ["repo", "name"]) || "unknown"
    branch = branch_name(get_in(event, ["payload", "ref"]))
    commits = commit_summaries(repo, get_in(event, ["payload", "commits"]) || [])
    category = category_for_repo(repo)

    %{
      id: event["id"],
      type: event_type(event["type"]),
      raw_type: event["type"],
      repo: repo,
      repo_url: repo_url(event),
      created_at: parse_timestamp(event["created_at"]),
      created_at_label: format_timestamp(event["created_at"]),
      branch: branch,
      commits: commits,
      category: category,
      action: get_in(event, ["payload", "action"]),
      pr_url: get_in(event, ["payload", "pull_request", "html_url"]),
      pr_number: get_in(event, ["payload", "number"])
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
    case parse_timestamp(timestamp) do
      %DateTime{} = datetime ->
        Calendar.strftime(datetime, "%b %d, %Y")

      _ ->
        timestamp
    end
  end

  defp parse_timestamp(nil), do: nil

  defp parse_timestamp(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, datetime, _offset} ->
        datetime

      _ ->
        nil
    end
  end

  defp branch_name(nil), do: nil

  defp branch_name(ref) do
    String.replace_prefix(ref, "refs/heads/", "")
  end

  defp commit_summaries(repo, commits) do
    commits
    |> Enum.take(3)
    |> Enum.map(fn commit ->
      sha = commit["sha"] || ""

      %{
        sha: sha,
        short_sha: String.slice(sha, 0, 7),
        message: first_line(commit["message"]),
        url: commit_url(repo, sha)
      }
    end)
  end

  defp commit_url(_repo, ""), do: nil
  defp commit_url("unknown", _sha), do: nil
  defp commit_url(repo, sha), do: "#{@base_site}/#{repo}/commit/#{sha}"

  defp first_line(nil), do: "Commit"

  defp first_line(message) do
    message
    |> String.split("\n")
    |> List.first()
  end

  defp category_for_repo("unknown"), do: :personal

  defp category_for_repo(repo) do
    owner =
      repo
      |> String.split("/")
      |> List.first()
      |> to_string()
      |> String.downcase()

    tracked_owners = Enum.map(@users, &String.downcase/1)

    if owner in tracked_owners, do: :personal, else: :open_source
  end

  defp activity_priority(%{category: :open_source}), do: 0
  defp activity_priority(_event), do: 1

  defp sort_key(%{created_at: %DateTime{} = created_at}), do: created_at
  defp sort_key(_event), do: ~U[1970-01-01 00:00:00Z]

  defp activity_before?(left, right) do
    cond do
      activity_priority(left) < activity_priority(right) ->
        true

      activity_priority(left) > activity_priority(right) ->
        false

      DateTime.compare(left.sort_key, right.sort_key) == :gt ->
        true

      DateTime.compare(left.sort_key, right.sort_key) == :lt ->
        false

      true ->
        to_string(left.id) <= to_string(right.id)
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

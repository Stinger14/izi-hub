defmodule Core.Notebooks do
  @moduledoc """
  	Fetches and renders Livebooks notebooks (.livemd) in Github
  """

  @github_owner "Stinger14"
  @github_repo "izi-hub"
  @github_branch "main"
  @github_path "priv/notebooks"

  @base_api "https://api.github.com"
  @base_raw "https://raw.githubusercontent.com"

  @cache_table __MODULE__.Cache
  @cache_ttl_seconds 300

  def list_notebooks do
    with {:ok, entries} <- fetch_dir_listing() do
      entries
      |> Enum.filter(&String.ends_with?(&1["name"], ".livemd"))
      |> Enum.map(fn entry ->
        name = entry["name"]
        slug = String.replace_suffix(name, ".livemd", "")

        %{
          name: name,
          slug: slug,
          api_url: entry["url"],
          raw_url: raw_url(name)
        }
      end)
    end
  end

  def fetch_notebook(slug) do
    name = "#{slug}.livemd"

    with {:ok, content} <- fetch_raw_file(name) do
      {:ok, %{slug: slug, content: content, html: render_markdown(content)}}
    end
  end

  defp fetch_dir_listing do
    fetch_cache({:list, @github_owner, @github_repo, @github_branch, @github_path}, fn ->
      url =
        "#{@base_api}/repos/#{@github_owner}/#{@github_repo}/contents/#{@github_path}?ref=#{@github_branch}"

      request(url)
    end)
  end

  defp fetch_raw_file(name) do
    fetch_cache({:raw, name, @github_owner, @github_repo, @github_branch}, fn ->
      request_raw(raw_url(name))
    end)
  end

  defp raw_url(name) do
    "#{@base_raw}/#{@github_owner}/#{@github_repo}/#{@github_branch}/#{@github_path}/#{name}"
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

  defp request_raw(url) do
    url
    |> Req.get(headers: github_headers())
    |> case do
      {:ok, %{status: 200, body: body}} when is_binary(body) -> {:ok, body}
      {:ok, %{status: 200, body: body}} -> {:ok, to_string(body)}
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp github_headers do
    headers = [{"user-agent", "izi-hub"}]

    case System.get_env("GITHUB_TOKEN") do
      nil -> headers
      token -> [{"authorization", "Bearer #{token}"} | headers]
    end
  end

  defp render_markdown(content) do
    case Earmark.as_html(content) do
      {:ok, html, _} -> html
      {:error, html, _} -> html
    end
  end

  defp fetch_cache(key, fun) do
    ensure_cache_table!()

    now = System.system_time(:second)

    case :ets.lookup(@cache_table, key) do
      [{^key, {cached_at, value}}] when now - cached_at < @cache_ttl_seconds ->
        value

      _ ->
        value = fun.()
        :ets.insert(@cache_table, {key, {now, value}})
        value
    end
  end

  defp ensure_cache_table! do
    case :ets.whereis(@cache_table) do
      :undefined ->
        :ets.new(@cache_table, [:named_table, :public, :set, read_concurrency: true])
        :ok

      _ ->
        :ok
    end
  end
end

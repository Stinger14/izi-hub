defmodule Core.Notebooks do
  @moduledoc """
  Fetches and renders notebook previews in Markdown.
  """

  @github_owner "Stinger14"
  @github_repo "izi-hub"
  @github_branch "main"
  @github_path "backend/core/priv/notebooks"

  @base_api "https://api.github.com"
  @base_raw "https://raw.githubusercontent.com"

  @cache_table __MODULE__.Cache
  @cache_ttl_seconds 300
  @preview_extension ".md"
  @app_extension ".livemd"
  @local_dir Path.join(to_string(:code.priv_dir(:core)), "notebooks")

  def list_notebooks do
    case source_mode() do
      :local_first ->
        case list_local_notebooks() do
          {:ok, [_ | _] = notebooks} -> {:ok, notebooks}
          _ -> list_remote_notebooks()
        end

      :local ->
        list_local_notebooks()

      :github ->
        list_remote_notebooks()
    end
  end

  def fetch_notebook(slug) do
    case source_mode() do
      :local_first ->
        case fetch_local_notebook(slug) do
          {:ok, notebook} -> {:ok, notebook}
          _ -> fetch_remote_notebook(slug)
        end

      :local ->
        fetch_local_notebook(slug)

      :github ->
        fetch_remote_notebook(slug)
    end
  end

  def list_livebook_apps do
    with {:ok, entries} <- File.ls(@local_dir) do
      apps =
        entries
        |> Enum.filter(&String.ends_with?(&1, @app_extension))
        |> Enum.map(&build_livebook_app/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(& &1.slug)

      {:ok, apps}
    end
  end

  defp list_remote_notebooks do
    with {:ok, entries} <- fetch_dir_listing() do
      notebooks =
        entries
        |> Enum.filter(&String.ends_with?(&1["name"], @preview_extension))
        |> Enum.map(fn entry ->
          name = entry["name"]
          slug = String.replace_suffix(name, @preview_extension, "")

          %{
            name: name,
            slug: slug,
            api_url: entry["url"],
            raw_url: raw_url(name)
          }
        end)
        |> Enum.sort_by(& &1.slug)

      {:ok, notebooks}
    end
  end

  defp fetch_remote_notebook(slug) do
    name = "#{slug}#{@preview_extension}"

    with {:ok, content} <- fetch_raw_file(name) do
      {:ok,
       %{
         slug: slug,
         content: content,
         html: render_markdown(content)
       }}
    end
  end

  defp list_local_notebooks do
    with {:ok, entries} <- File.ls(@local_dir) do
      notebooks =
        entries
        |> Enum.filter(&String.ends_with?(&1, @preview_extension))
        |> Enum.map(fn name ->
          slug = String.replace_suffix(name, @preview_extension, "")

          %{
            name: name,
            slug: slug,
            api_url: nil,
            raw_url: nil
          }
        end)
        |> Enum.sort_by(& &1.slug)

      {:ok, notebooks}
    end
  end

  defp fetch_local_notebook(slug) do
    name = "#{slug}#{@preview_extension}"
    path = Path.join(@local_dir, name)

    with {:ok, content} <- File.read(path) do
      {:ok,
       %{
         slug: slug,
         content: content,
         html: render_markdown(content)
       }}
    end
  end

  defp build_livebook_app(name) do
    slug = String.replace_suffix(name, @app_extension, "")
    path = Path.join(@local_dir, name)

    with {:ok, content} <- File.read(path) do
      {meta, _body} = parse_frontmatter(content)
      url = Map.get(meta, "url") || app_url_from_env(slug)

      %{
        name: name,
        slug: slug,
        title: Map.get(meta, "title") || slug,
        description: Map.get(meta, "description") || "Live app from Livebook.",
        url: url
      }
    else
      _ -> nil
    end
  end

  defp parse_frontmatter(content) do
    lines = String.split(content, ~r/\r?\n/)

    case lines do
      ["---" | rest] ->
        {front_lines, remainder} = Enum.split_while(rest, &(&1 != "---"))

        case remainder do
          ["---" | body_lines] ->
            {parse_frontmatter_lines(front_lines), Enum.join(body_lines, "\n")}

          _ ->
            {%{}, content}
        end

      _ ->
        {%{}, content}
    end
  end

  defp parse_frontmatter_lines(lines) do
    Enum.reduce(lines, %{}, fn line, acc ->
      case String.split(line, ":", parts: 2) do
        [key, value] ->
          Map.put(acc, String.trim(key), value |> String.trim() |> trim_quotes())

        _ ->
          acc
      end
    end)
  end

  defp trim_quotes(value) do
    trimmed = String.trim(value)

    cond do
      String.starts_with?(trimmed, "\"") and String.ends_with?(trimmed, "\"") ->
        trimmed |> String.trim_leading("\"") |> String.trim_trailing("\"")

      String.starts_with?(trimmed, "'") and String.ends_with?(trimmed, "'") ->
        trimmed |> String.trim_leading("'") |> String.trim_trailing("'")

      true ->
        trimmed
    end
  end

  defp app_url_from_env(slug) do
    base =
      System.get_env("LIVEBOOK_APPS_BASE_URL") ||
        Application.get_env(:core, __MODULE__, [])
        |> Keyword.get(:livebook_apps_base_url)

    if is_binary(base) and base != "" do
      base = String.trim_trailing(base, "/")
      "#{base}/#{URI.encode(slug)}"
    end
  end

  defp source_mode do
    env_override =
      case System.get_env("NOTEBOOKS_SOURCE") do
        "local" -> :local
        "github" -> :github
        "local_first" -> :local_first
        _ -> nil
      end

    env_override ||
      case Application.get_env(:core, __MODULE__, []) do
        config when is_list(config) ->
          case Keyword.get(config, :source) do
            :local -> :local
            :github -> :github
            :local_first -> :local_first
            _ -> default_source_mode()
          end

        _ ->
          default_source_mode()
      end
  end

  defp default_source_mode do
    if Code.ensure_loaded?(Mix) and Mix.env() == :dev do
      :local_first
    else
      :github
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

    case github_token() do
      token when is_binary(token) and token != "" ->
        [{"authorization", "Bearer #{token}"} | headers]

      _ ->
        headers
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

  defp github_token do
    case Core.Config.github_token() do
      {:ok, token} when is_binary(token) -> String.trim(token)
      _ -> ""
    end
  end
end

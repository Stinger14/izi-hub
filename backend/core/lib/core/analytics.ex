defmodule Core.Analytics do
  @moduledoc """
  Anonymous page-view tracking and the stats built on it, plus report records.

  Context: `CvController` records CV downloads; the admin dashboard and
  Analytics page read counts, top pages and device/browser/country breakdowns.

  ## Example

      Analytics.record_page_view(%{page_path: "/cv/download", session_id: sid})
      Analytics.count_page_views("/cv/download")
  """

  import Ecto.Query, warn: false
  alias Core.Repo

  alias Core.Analytics.{PageView, Report}

  # Page Views

  @doc "Stores one page view. `{:ok, view}` or `{:error, changeset}`."
  def record_page_view(attrs) do
    %PageView{}
    |> PageView.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Views of one path, newest first (`:limit` default 100, `:start_date`, `:end_date`)."
  def list_page_views(page_path, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    start_date = Keyword.get(opts, :start_date)
    end_date = Keyword.get(opts, :end_date)

    query =
      PageView
      |> where([pv], pv.page_path == ^page_path)
      |> order_by([pv], desc: pv.inserted_at)
      |> limit(^limit)

    query =
      if start_date do
        where(query, [pv], pv.inserted_at >= ^start_date)
      else
        query
      end

    query =
      if end_date do
        where(query, [pv], pv.inserted_at <= ^end_date)
      else
        query
      end

    Repo.all(query)
  end

  @doc "Number of views, for one path or all. Optional `start_date`/`end_date` limit the range."
  def count_page_views(page_path \\ nil, start_date \\ nil, end_date \\ nil) do
    query = PageView

    query =
      if page_path do
        where(query, [pv], pv.page_path == ^page_path)
      else
        query
      end

    query =
      if start_date do
        where(query, [pv], pv.inserted_at >= ^start_date)
      else
        query
      end

    query =
      if end_date do
        where(query, [pv], pv.inserted_at <= ^end_date)
      else
        query
      end

    Repo.aggregate(query, :count)
  end

  @doc "Distinct sessions that viewed a path. Optional `start_date`/`end_date` limit the range."
  def count_unique_page_sessions(page_path, start_date \\ nil, end_date \\ nil) do
    query =
      PageView
      |> where([pv], pv.page_path == ^page_path)
      |> where([pv], not is_nil(pv.session_id))

    query =
      if start_date do
        where(query, [pv], pv.inserted_at >= ^start_date)
      else
        query
      end

    query =
      if end_date do
        where(query, [pv], pv.inserted_at <= ^end_date)
      else
        query
      end

    query
    |> select([pv], count(fragment("DISTINCT ?", pv.session_id)))
    |> Repo.one()
  end

  @doc "Distinct sessions across all pages. Optional `start_date`/`end_date` limit the range."
  def count_unique_sessions(start_date \\ nil, end_date \\ nil) do
    query =
      PageView
      |> where([pv], not is_nil(pv.session_id))

    query =
      if start_date do
        where(query, [pv], pv.inserted_at >= ^start_date)
      else
        query
      end

    query =
      if end_date do
        where(query, [pv], pv.inserted_at <= ^end_date)
      else
        query
      end

    query
    |> select([pv], count(fragment("DISTINCT ?", pv.session_id)))
    |> Repo.one()
  end

  @doc "When a path (or any page) was last viewed, or nil."
  def last_page_viewed_at(page_path \\ nil) do
    query =
      if page_path do
        where(PageView, [pv], pv.page_path == ^page_path)
      else
        PageView
      end

    query
    |> order_by([pv], desc: pv.inserted_at)
    |> limit(1)
    |> select([pv], pv.inserted_at)
    |> Repo.one()
  end

  @doc """
  The `limit` most viewed paths with counts. Optional `start_date`/`end_date` limit
  the range.
  """
  def get_top_pages(limit \\ 10, start_date \\ nil, end_date \\ nil) do
    query =
      PageView
      |> group_by([pv], pv.page_path)
      |> select([pv], {pv.page_path, count(pv.id)})
      |> order_by([pv], desc: count(pv.id))
      |> limit(^limit)

    query =
      if start_date do
        where(query, [pv], pv.inserted_at >= ^start_date)
      else
        query
      end

    query =
      if end_date do
        where(query, [pv], pv.inserted_at <= ^end_date)
      else
        query
      end

    Repo.all(query)
    |> Enum.map(fn {path, count} -> %{page_path: path, views: count} end)
  end

  @doc "Latest views across all pages (`:limit` default 50, `:start_date`, `:end_date`)."
  def list_recent_page_views(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    start_date = Keyword.get(opts, :start_date)
    end_date = Keyword.get(opts, :end_date)

    query =
      PageView
      |> order_by([pv], desc: pv.inserted_at)
      |> limit(^limit)

    query =
      if start_date do
        where(query, [pv], pv.inserted_at >= ^start_date)
      else
        query
      end

    query =
      if end_date do
        where(query, [pv], pv.inserted_at <= ^end_date)
      else
        query
      end

    Repo.all(query)
  end

  @doc "View counts per device type. Optional `start_date`/`end_date` limit the range."
  def get_devices_breakdown(start_date \\ nil, end_date \\ nil) do
    query =
      PageView
      |> group_by([pv], pv.device_type)
      |> select([pv], {pv.device_type, count(pv.id)})

    query =
      if start_date do
        where(query, [pv], pv.inserted_at >= ^start_date)
      else
        query
      end

    query =
      if end_date do
        where(query, [pv], pv.inserted_at <= ^end_date)
      else
        query
      end

    Repo.all(query)
    |> Enum.map(fn {device_type, count} -> %{device_type: device_type, count: count} end)
  end

  @doc "View counts per browser. Optional `start_date`/`end_date` limit the range."
  def get_browsers_breakdown(start_date \\ nil, end_date \\ nil) do
    query =
      PageView
      |> group_by([pv], pv.browser)
      |> select([pv], {pv.browser, count(pv.id)})

    query =
      if start_date do
        where(query, [pv], pv.inserted_at >= ^start_date)
      end

    query =
      if end_date do
        where(query, [pv], pv.inserted_at <= ^end_date)
      end

    Repo.all(query)
    |> Enum.map(fn {browser, count} -> %{browser: browser, count: count} end)
  end

  @doc "View counts per country. Optional `start_date`/`end_date` limit the range."
  def get_geographic_distribution(start_date \\ nil, end_date \\ nil) do
    query =
      PageView
      |> group_by([pv], [pv.country, pv.city])
      |> select([pv], {pv.country, pv.city, count(pv.id)})
      |> order_by([pv], desc: count(pv.id))

    query =
      if start_date do
        where(query, [pv], pv.inserted_at >= ^start_date)
      end

    query =
      if end_date do
        where(query, [pv], pv.inserted_at <= ^end_date)
      end

    Repo.all(query)
    |> Enum.map(fn {country, city, count} ->
      %{
        country: country,
        city: city,
        count: count
      }
    end)
  end

  @doc "Deletes views older than `days_old` days (default 90)."
  def delete_old_page_views(days_old \\ 90) do
    cutoff_date =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-days_old * 24 * 3600)

    from(pv in PageView, where: pv.inserted_at < ^cutoff_date)
    |> Repo.delete_all()
  end

  # Reports
  @doc "A user's reports, newest first."
  def list_reports(user_id) do
    Report
    |> where([r], r.user_id == ^user_id)
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  @doc "A report by id; raises if missing."
  def get_report!(id) do
    Report
    |> preload(:user)
    |> Repo.get!(id)
  end

  @doc "Creates a report request."
  def create_report(attrs) do
    %Report{}
    |> Report.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a report."
  def update_report(%Report{} = report, attrs \\ %{}) do
    report
    |> Report.changeset(attrs)
    |> Repo.update()
  end

  @doc "Marks a report done with its file URL and result data."
  def mark_report_completed(%Report{} = report, file_url, result_data \\ %{}) do
    report
    |> Report.changeset(%{
      status: "completed",
      file_url: file_url,
      result_data: result_data,
      generated_at: NaiveDateTime.utc_now()
    })
    |> Repo.update()
  end

  @doc "Marks a report failed with an error message."
  def mark_report_failed(%Report{} = report, error_msg) do
    report
    |> Report.changeset(%{
      status: "failed",
      error_msg: error_msg
    })
    |> Repo.update()
  end

  @doc "Deletes a report."
  def delete_report(%Report{} = report) do
    Repo.delete(report)
  end
end

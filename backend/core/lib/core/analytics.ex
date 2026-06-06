defmodule Core.Analytics do
  @moduledoc """
  The Analytics context.
  """

  import Ecto.Query, warn: false
  alias Core.Repo

  alias Core.Analytics.{PageView, Report}

  # Page Views

  @doc """
  Records a page view
  """
  def record_page_view(attrs) do
    %PageView{}
    |> PageView.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns page views for a specific page path
  """
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

  @doc """
  Returns total page views count
  """
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

  @doc """
  Counts unique sessions for a specific page path.
  """
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

  @doc """
  Counts unique sessions across all tracked page views.
  """
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

  @doc """
  Returns the timestamp of the most recent page view for a given path.
  """
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
  Returns most viewed pages
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

  @doc """
  Returns the most recent tracked page views across all pages.
  """
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

  @doc """
  Returns device type breakdown
  """
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

  @doc """
  Returns browser breakdown
  """
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

  @doc """
  Returns geographic distribution
  """
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

  @doc """
  Delete all page views older than a given date(Clean up)
  """
  def delete_old_page_views(days_old \\ 90) do
    cutoff_date =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-days_old * 24 * 3600)

    from(pv in PageView, where: pv.inserted_at < ^cutoff_date)
    |> Repo.delete_all()
  end

  # Reports
  @doc """
  Returns a list of reports for a user
  """
  def list_reports(user_id) do
    Report
    |> where([r], r.user_id == ^user_id)
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single report
  """
  def get_report!(id) do
    Report
    |> preload(:user)
    |> Repo.get!(id)
  end

  @doc """
  Creates a report
  """
  def create_report(attrs) do
    %Report{}
    |> Report.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a report
  """
  def update_report(%Report{} = report, attrs \\ %{}) do
    report
    |> Report.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Marks report as completed
  """
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

  @doc """
  Marks report as failed
  """
  def mark_report_failed(%Report{} = report, error_msg) do
    report
    |> Report.changeset(%{
      status: "failed",
      error_msg: error_msg
    })
    |> Repo.update()
  end

  @doc """
  Deletes a report
  """
  def delete_report(%Report{} = report) do
    Repo.delete(report)
  end
end

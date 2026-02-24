defmodule CoreWeb.CVController do
  use CoreWeb, :controller

  require Logger

  alias Core.Analytics

  @cv_download_path "/cv/download"

  def download(conn, _params) do
    conn =
      conn
      |> ensure_analytics_session_id()
      |> track_cv_download()

    cv_path = Path.join(:code.priv_dir(:core), "static/maxly_garcia_cv.pdf")

    if File.exists?(cv_path) do
      send_download(conn, {:file, cv_path},
        filename: "maxly_garcia_cv.pdf",
        disposition: :attachment
      )
    else
      conn
      |> put_status(:not_found)
      |> text("CV file not found")
    end
  end

  defp ensure_analytics_session_id(conn) do
    case get_session(conn, :analytics_session_id) do
      nil ->
        put_session(conn, :analytics_session_id, Ecto.UUID.generate())

      _session_id ->
        conn
    end
  end

  defp track_cv_download(conn) do
    attrs = %{
      page_path: @cv_download_path,
      referrer: header_value(conn, "referer"),
      user_agent: header_value(conn, "user-agent"),
      session_id: get_session(conn, :analytics_session_id)
    }

    case Analytics.record_page_view(attrs) do
      {:ok, _page_view} ->
        conn

      {:error, changeset} ->
        Logger.warning("failed_to_track_cv_download: #{inspect(changeset.errors)}")
        conn
    end
  end

  defp header_value(conn, key) do
    conn
    |> get_req_header(key)
    |> List.first()
  end
end

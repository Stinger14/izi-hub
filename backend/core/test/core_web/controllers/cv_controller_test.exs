defmodule CoreWeb.CVControllerTest do
  use CoreWeb.ConnCase, async: true

  alias Core.Analytics

  describe "GET /cv" do
    test "tracks and serves the CV download", %{conn: conn} do
      assert Analytics.count_page_views("/cv/download") == 0

      conn = get(conn, ~p"/cv")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["application/pdf"]

      [content_disposition] = get_resp_header(conn, "content-disposition")
      assert content_disposition =~ "attachment"
      assert content_disposition =~ "maxly_garcia_cv.pdf"
      assert Analytics.count_page_views("/cv/download") == 1
    end

    test "reuses analytics session for repeated downloads", %{conn: conn} do
      conn = get(conn, ~p"/cv")
      conn = recycle(conn)
      _conn = get(conn, ~p"/cv")

      assert Analytics.count_page_views("/cv/download") == 2
      assert Analytics.count_unique_page_sessions("/cv/download") == 1
    end
  end
end

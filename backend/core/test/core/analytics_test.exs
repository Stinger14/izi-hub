defmodule Core.AnalyticsTest do
  use Core.DataCase, async: true

  alias Core.Analytics
  alias Core.Analytics.PageView
  alias Core.Repo

  describe "page view helpers" do
    test "counts unique sessions for a page path" do
      Repo.insert!(%PageView{page_path: "/cv/download", session_id: "session-a"})
      Repo.insert!(%PageView{page_path: "/cv/download", session_id: "session-a"})
      Repo.insert!(%PageView{page_path: "/cv/download", session_id: "session-b"})
      Repo.insert!(%PageView{page_path: "/hub", session_id: "session-c"})

      assert Analytics.count_unique_page_sessions("/cv/download") == 2
    end

    test "returns last viewed timestamp for a page path" do
      older = ~N[2026-01-10 10:00:00]
      newer = ~N[2026-01-11 10:00:00]

      Repo.insert!(%PageView{
        page_path: "/cv/download",
        session_id: "session-a",
        inserted_at: older
      })

      Repo.insert!(%PageView{
        page_path: "/cv/download",
        session_id: "session-b",
        inserted_at: newer
      })

      assert Analytics.last_page_viewed_at("/cv/download") == newer
    end
  end
end

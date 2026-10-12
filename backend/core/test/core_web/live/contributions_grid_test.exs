defmodule CoreWeb.ContributionsGridTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias CoreWeb.ContributionsLive

  test "renders the total, a tooltip per day and level styling" do
    calendar = %{
      total: 8,
      weeks: [
        [
          %{date: ~D[2026-10-05], count: 1, level: 1, weekday: 1},
          %{date: ~D[2026-10-06], count: 7, level: 4, weekday: 2}
        ]
      ]
    }

    html = render_component(&ContributionsLive.contribution_grid/1, calendar: calendar)

    assert html =~ "8 contributions in the last year"
    assert html =~ ~s(title="1 contribution on Oct 5, 2026")
    assert html =~ ~s(title="7 contributions on Oct 6, 2026")
    assert html =~ "bg-[var(--hub-accent-2)]"
  end

  test "pads a first week that starts mid-week onto the right weekday row" do
    calendar = %{
      total: 0,
      weeks: [[%{date: ~D[2026-10-07], count: 0, level: 0, weekday: 3}]]
    }

    html = render_component(&ContributionsLive.contribution_grid/1, calendar: calendar)
    pads = Regex.scan(~r/<span class="h-\[11px\] w-\[11px\]"><\/span>/, html)

    assert length(pads) == 3
  end
end

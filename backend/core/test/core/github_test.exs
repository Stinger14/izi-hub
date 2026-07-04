defmodule Core.GitHubTest do
  use Core.DataCase, async: true

  alias Core.GitHub

  test "prioritizes open source activity ahead of personal activity" do
    accounts = [
      %{
        username: "Stinger14",
        events: [
          %{
            id: "1",
            repo: "Stinger14/izi-hub",
            category: :personal,
            created_at: ~U[2026-06-05 12:00:00Z],
            created_at_label: "Jun 05, 2026",
            commits: [],
            branch: "main",
            type: "Push"
          },
          %{
            id: "2",
            repo: "phoenixframework/phoenix",
            category: :open_source,
            created_at: ~U[2026-06-04 12:00:00Z],
            created_at_label: "Jun 04, 2026",
            commits: [],
            branch: "fix-issue",
            type: "Pull Request"
          }
        ]
      }
    ]

    assert [first, second] = GitHub.build_activity_feed(accounts)
    assert first.repo == "phoenixframework/phoenix"
    assert second.repo == "Stinger14/izi-hub"
  end

  test "summarizes commits and repositories from the activity feed" do
    accounts = [
      %{
        username: "ghost1ndshell",
        events: [
          %{
            id: "1",
            repo: "elixir-lang/elixir",
            category: :open_source,
            created_at: ~U[2026-06-05 12:00:00Z],
            created_at_label: "Jun 05, 2026",
            commits: [
              %{message: "Improve docs"},
              %{message: "Tighten examples"}
            ],
            branch: "docs-pass",
            type: "Push"
          },
          %{
            id: "2",
            repo: "ghost1ndshell/lab",
            category: :personal,
            created_at: ~U[2026-06-04 12:00:00Z],
            created_at_label: "Jun 04, 2026",
            commits: [%{message: "Prototype layout"}],
            branch: "main",
            type: "Push"
          }
        ]
      }
    ]

    summary = GitHub.activity_summary(accounts)

    assert summary.commits_count == 3
    assert summary.repos_touched == 2
    assert summary.open_source_repos == 1
    assert summary.last_activity_at == "Jun 05, 2026"
  end
end

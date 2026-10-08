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

  describe "parse_contribution_calendar/1" do
    test "maps weeks, counts and quartile levels" do
      body = %{
        "data" => %{
          "user" => %{
            "contributionsCollection" => %{
              "contributionCalendar" => %{
                "totalContributions" => 7,
                "weeks" => [
                  %{
                    "contributionDays" => [
                      %{
                        "date" => "2026-10-04",
                        "contributionCount" => 0,
                        "contributionLevel" => "NONE",
                        "weekday" => 0
                      },
                      %{
                        "date" => "2026-10-05",
                        "contributionCount" => 7,
                        "contributionLevel" => "FOURTH_QUARTILE",
                        "weekday" => 1
                      }
                    ]
                  }
                ]
              }
            }
          }
        }
      }

      assert {:ok, %{total: 7, weeks: [[first, second]]}} =
               GitHub.parse_contribution_calendar(body)

      assert first == %{date: ~D[2026-10-04], count: 0, level: 0, weekday: 0}
      assert second == %{date: ~D[2026-10-05], count: 7, level: 4, weekday: 1}
    end

    test "surfaces GraphQL errors" do
      assert {:error, {:graphql, [%{"message" => "Bad credentials"}]}} =
               GitHub.parse_contribution_calendar(%{
                 "errors" => [%{"message" => "Bad credentials"}]
               })
    end

    test "reports an unknown user" do
      assert {:error, :user_not_found} =
               GitHub.parse_contribution_calendar(%{"data" => %{"user" => nil}})
    end

    test "rejects unexpected payloads" do
      assert {:error, :unexpected_shape} = GitHub.parse_contribution_calendar("<html>")
    end
  end
end

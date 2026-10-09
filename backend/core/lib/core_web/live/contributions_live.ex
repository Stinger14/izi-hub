defmodule CoreWeb.ContributionsLive do
  use CoreWeb, :live_view

  alias Core.GitHub

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign(
        github_accounts: [],
        loading_data: false,
        activity_feed: [],
        summary: %{
          commits_count: 0,
          repos_touched: 0,
          open_source_repos: 0,
          last_activity_at: "No recent activity"
        }
      )

    socket =
      if connected?(socket) do
        send(self(), :load_contributions)
        assign(socket, :loading_data, true)
      else
        socket
      end

    {:ok, socket}
  end

  def handle_info(:load_contributions, socket) do
    github_accounts = GitHub.fetch_accounts()
    activity_feed = GitHub.build_activity_feed(github_accounts)
    summary = GitHub.activity_summary(github_accounts)

    {:noreply,
     assign(socket,
       github_accounts: github_accounts,
       activity_feed: activity_feed,
       summary: summary,
       loading_data: false
     )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen">
        <header class="border-b border-[color:var(--hub-border)]">
          <div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
            <div>
              <p class="font-display text-lg text-[var(--hub-accent-2)]">Contributions</p>
            </div>
            <a href={~p"/hub"} class="btn btn-secondary btn-sm">Back to hub</a>
          </div>
        </header>

        <main class="mx-auto max-w-6xl px-6 pb-16 pt-12">
          <section>
            <p class="text-sm font-medium text-[var(--hub-accent-2)]">Activity overview</p>
            <h1 class="font-display mt-3 text-3xl text-[var(--hub-text)] sm:text-4xl">
              GitHub contribution details
            </h1>
            <p class="mt-3 text-sm text-[var(--hub-muted)]">
              Open source activity is prioritized first, followed by personal work and branch-level commit logs from recent public events.
            </p>
          </section>

          <section class="mt-10">
            <div class="flex items-center justify-between">
              <h2 class="font-display text-2xl text-[var(--hub-text)]">Contribution maps</h2>
              <a href="https://github.com" class="btn btn-secondary btn-sm">View GitHub</a>
            </div>

            <%= if @loading_data and @github_accounts == [] do %>
              <p class="mt-6 text-sm text-[var(--hub-muted)]">Loading contribution maps...</p>
            <% else %>
              <%= if @github_accounts == [] do %>
                <p class="mt-6 text-sm text-[var(--hub-muted)]">No GitHub accounts loaded.</p>
              <% else %>
                <div class="mt-8 grid gap-6">
                  <%= for account <- @github_accounts do %>
                    <div class="hub-glass rounded-2xl p-6">
                      <div class="flex items-center justify-between">
                        <h3 class="text-base font-semibold text-[var(--hub-text)]"><%= account.username %></h3>
                        <a href={account.repo_url} class="btn btn-ghost btn-xs">Profile</a>
                      </div>

                      <div class="mt-4 rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] p-3">
                        <%= if account.contributions do %>
                          <.contribution_grid calendar={account.contributions} />
                        <% else %>
                          <p class="text-sm text-[var(--hub-muted)]">Contribution map unavailable.</p>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            <% end %>
          </section>

          <section class="mt-10 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <div class="hub-glass rounded-2xl p-5">
              <p class="text-xs font-semibold uppercase tracking-wide text-[var(--hub-muted)]">Commits</p>
              <p class="font-display mt-3 text-3xl text-[var(--hub-text)]"><%= @summary.commits_count %></p>
              <p class="mt-1 text-xs text-[var(--hub-muted)]">Recent commits visible from public events</p>
            </div>

            <div class="hub-glass rounded-2xl p-5">
              <p class="text-xs font-semibold uppercase tracking-wide text-[var(--hub-muted)]">Repos Touched</p>
              <p class="font-display mt-3 text-3xl text-[var(--hub-text)]"><%= @summary.repos_touched %></p>
              <p class="mt-1 text-xs text-[var(--hub-muted)]">Distinct repositories in the current activity window</p>
            </div>

            <div class="hub-glass rounded-2xl p-5">
              <p class="text-xs font-semibold uppercase tracking-wide text-[var(--hub-muted)]">Open Source Repos</p>
              <p class="font-display mt-3 text-3xl text-[var(--hub-text)]"><%= @summary.open_source_repos %></p>
              <p class="mt-1 text-xs text-[var(--hub-muted)]">Repositories outside the tracked personal accounts</p>
            </div>

            <div class="hub-glass rounded-2xl p-5">
              <p class="text-xs font-semibold uppercase tracking-wide text-[var(--hub-muted)]">Latest Activity</p>
              <p class="mt-3 text-sm font-semibold text-[var(--hub-text)]"><%= @summary.last_activity_at %></p>
              <p class="mt-1 text-xs text-[var(--hub-muted)]">Most recent event in this feed</p>
            </div>
          </section>

          <section class="mt-10">
            <div class="flex items-center justify-between">
              <div>
                <h2 class="font-display text-2xl text-[var(--hub-text)]">Branch activity log</h2>
                <p class="mt-1 text-sm text-[var(--hub-muted)]">
                  Ordered with open source work first, then personal repositories.
                </p>
              </div>
            </div>

            <%= if @loading_data and @activity_feed == [] do %>
              <p class="mt-6 text-sm text-[var(--hub-muted)]">Loading activity log...</p>
            <% else %>
              <%= if @activity_feed == [] do %>
                <p class="mt-6 text-sm text-[var(--hub-muted)]">No recent public activity loaded.</p>
              <% else %>
                <div class="mt-8 space-y-8">
                  <div :for={{title, items} <- activity_sections(@activity_feed)} class="space-y-4">
                    <div class="flex items-center gap-3">
                      <h3 class="text-lg font-semibold text-[var(--hub-text)]"><%= title %></h3>
                      <span class="rounded-full bg-[color:var(--hub-accent)]/15 px-2.5 py-1 text-xs font-semibold text-[var(--hub-accent-2)]">
                        <%= length(items) %> entries
                      </span>
                    </div>

                    <div class="space-y-4">
                      <article
                        :for={entry <- items}
                        class="hub-glass rounded-2xl p-5"
                      >
                        <div class="flex flex-wrap items-start justify-between gap-3">
                          <div>
                            <div class="flex flex-wrap items-center gap-2">
                              <a href={entry.repo_url} class="text-base font-semibold text-[var(--hub-text)] hover:text-[var(--hub-accent-2)]">
                                <%= entry.repo %>
                              </a>
                              <span class={category_badge_class(entry.category)}>
                                <%= category_label(entry.category) %>
                              </span>
                            </div>

                            <div class="mt-2 flex flex-wrap items-center gap-2 text-xs text-[var(--hub-muted)]">
                              <span>Account: <%= entry.account_username %></span>
                              <span>•</span>
                              <span><%= entry.type %></span>
                              <%= if entry.branch do %>
                                <span>•</span>
                                <span>Branch: <code><%= entry.branch %></code></span>
                              <% end %>
                            </div>
                          </div>

                          <div class="text-right text-xs text-[var(--hub-muted)]">
                            <p><%= entry.created_at_label %></p>
                            <%= if entry.pr_url do %>
                              <a href={entry.pr_url} class="mt-2 inline-flex text-[var(--hub-secondary)] hover:text-[var(--hub-accent-2)]">
                                View PR #<%= entry.pr_number %>
                              </a>
                            <% end %>
                          </div>
                        </div>

                        <%= if entry.commits == [] do %>
                          <p class="mt-4 text-sm text-[var(--hub-muted)]">
                            <%= activity_summary_line(entry) %>
                          </p>
                        <% else %>
                          <div class="mt-4 rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] p-4">
                            <p class="text-xs font-semibold uppercase tracking-wide text-[var(--hub-muted)]">Recent commits</p>
                            <ul class="mt-3 space-y-3">
                              <li :for={commit <- entry.commits} class="flex items-start justify-between gap-3">
                                <div>
                                  <p class="text-sm font-medium text-[var(--hub-text)]"><%= commit.message %></p>
                                  <p class="mt-1 text-xs text-[var(--hub-muted)]">
                                    <%= if commit.short_sha != "" do %>
                                      SHA <%= commit.short_sha %>
                                    <% else %>
                                      Commit
                                    <% end %>
                                  </p>
                                </div>

                                <%= if commit.url do %>
                                  <a href={commit.url} class="btn btn-ghost btn-xs">Commit</a>
                                <% end %>
                              </li>
                            </ul>
                          </div>
                        <% end %>
                      </article>
                    </div>
                  </div>
                </div>
              <% end %>
            <% end %>
          </section>
        </main>
      </div>
    </Layouts.app>
    """
  end

  defp activity_sections(feed) do
    open_source = Enum.filter(feed, &(&1.category == :open_source))
    personal = Enum.reject(feed, &(&1.category == :open_source))

    [{"Open source", open_source}, {"Personal and tracked accounts", personal}]
    |> Enum.reject(fn {_title, items} -> items == [] end)
  end

  defp category_label(:open_source), do: "Open source"
  defp category_label(_category), do: "Personal"

  attr :calendar, :map, required: true

  @doc false
  def contribution_grid(assigns) do
    ~H"""
    <div>
      <p class="text-xs text-[var(--hub-muted)]">
        <%= @calendar.total %> contributions in the last year
      </p>
      <div class="mt-3 overflow-x-auto pb-1">
        <div class="grid w-max grid-flow-col grid-rows-7 gap-[3px]">
          <%= for {week, idx} <- Enum.with_index(@calendar.weeks) do %>
            <%!-- the first week can start mid-week: pad so it lines up on the right weekday row --%>
            <span :for={_ <- leading_pad(week, idx)} class="h-[11px] w-[11px]"></span>
            <span
              :for={day <- week}
              title={contribution_title(day)}
              class={["h-[11px] w-[11px] rounded-[3px]", contribution_level_class(day.level)]}
            >
            </span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp leading_pad([%{weekday: weekday} | _], 0), do: List.duplicate(nil, weekday)
  defp leading_pad(_week, _idx), do: []

  defp contribution_title(%{count: 1, date: date}),
    do: "1 contribution on #{Calendar.strftime(date, "%b %-d, %Y")}"

  defp contribution_title(%{count: count, date: date}),
    do: "#{count} contributions on #{Calendar.strftime(date, "%b %-d, %Y")}"

  defp contribution_level_class(0),
    do: "bg-[var(--hub-surface)] ring-1 ring-inset ring-[color:var(--hub-border)]"

  defp contribution_level_class(1), do: "bg-[color:var(--hub-accent)]/30"
  defp contribution_level_class(2), do: "bg-[color:var(--hub-accent)]/55"
  defp contribution_level_class(3), do: "bg-[color:var(--hub-accent)]/80"
  defp contribution_level_class(_), do: "bg-[var(--hub-accent-2)]"

  defp category_badge_class(:open_source) do
    [
      "rounded-full px-2.5 py-1 text-xs font-semibold",
      CoreWeb.FinanceComponents.tone_class("income", :soft)
    ]
  end

  defp category_badge_class(_category) do
    [
      "rounded-full px-2.5 py-1 text-xs font-semibold",
      CoreWeb.FinanceComponents.tone_class("muted", :soft)
    ]
  end

  defp activity_summary_line(%{action: action, type: type})
       when is_binary(action) and action != "" do
    "#{type} action: #{action}"
  end

  defp activity_summary_line(%{type: type, branch: branch})
       when is_binary(branch) and branch != "" do
    "#{type} on branch #{branch}"
  end

  defp activity_summary_line(%{type: type}), do: type
end

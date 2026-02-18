defmodule CoreWeb.HubLive do
  use CoreWeb, :live_view

  alias Core.GitHub
  alias Core.HackerNews
  alias CoreWeb.Presence

  @presence_topic "site:presence"

  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        current_scope: nil,
        github_accounts: [],
        news_items: [],
        loading_data: false,
        online_count: 0
      )

    socket =
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Core.PubSub, @presence_topic)
        _ = Presence.track(self(), @presence_topic, presence_key(), %{joined_at: now_unix()})
        online_count = online_count()

        send(self(), :load_hub_data)

        assign(socket, loading_data: true, online_count: online_count)
      else
        socket
      end

    {:ok, socket}
  end

  def handle_info(:load_hub_data, socket) do
    github_accounts = GitHub.fetch_accounts()
    news_items = HackerNews.fetch_best_stories(limit: 7)

    {:noreply,
     assign(socket, github_accounts: github_accounts, news_items: news_items, loading_data: false)}
  end

  def handle_info(%{event: "presence_diff"}, socket) do
    {:noreply, assign(socket, online_count: online_count())}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
    <div class="min-h-screen bg-purple-50 text-slate-900">
      <header class="border-b border-purple-100 bg-white/70 backdrop-blur">
        <div class="mx-auto max-w-6xl px-6 py-5">
          <div class="flex items-center justify-between gap-6">
            <div class="text-lg font-semibold tracking-tight text-purple-600">IziHub</div>
            <nav class="hidden items-center gap-4 text-sm text-slate-600 md:flex">
              <a href="#links" class="fx-nav-link">Quick links</a>
              <a href={~p"/contributions"} class="fx-nav-link">Contributions</a>
              <a href={~p"/resources"} class="fx-nav-link">Resources</a>
              <a href="#week" class="fx-nav-link">This week</a>
            </nav>
            <div class="flex items-center gap-3">
            <div class="hidden items-center gap-2 rounded-full border border-purple-100 bg-white/80 px-3 py-1 text-xs font-medium text-slate-500 md:flex">
              <span class="h-2 w-2 rounded-full bg-emerald-400"></span>
              <span><%= @online_count %> online</span>
            </div>
              <span class="badge-status badge-wip">
                WIP
              </span>
              <a
                href={~p"/liveapps"}
                class="btn btn-primary btn-sm"
              >
                Liveapps
              </a>
            </div>
          </div>

        </div>
      </header>

      <main>
        <section class="mx-auto max-w-6xl px-6 pb-16 pt-16">
          <div class="grid items-start gap-12 lg:grid-cols-[minmax(0,1fr)_340px]">
            <div>
              <h1 class="mt-3 text-4xl font-semibold tracking-tight text-slate-900 sm:text-5xl">
                Hi, I’m Maxly García — software developer.
              </h1>
              <p class="mt-4 text-lg text-slate-600">
                I build practical, reliable systems and tools to make things simple.
              </p>
              <div class="mt-8 flex flex-wrap items-center gap-4">
                <a
                  href={~p"/profile"}
                  class="btn btn-primary btn-glow"
                >
                  View profile
                </a>
              </div>
              <div class="mt-10 rounded-2xl border border-purple-100 bg-white/80 p-6 shadow-sm">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">GitHub</p>
                    <h3 class="mt-1 text-lg font-semibold text-slate-900">Recent activity</h3>
                  </div>
                  <a href="https://github.com" class="btn btn-ghost btn-xs">
                    View GitHub
                  </a>
                </div>

                <div class="mt-6 grid gap-6">
                  <%= if @github_accounts == [] and @loading_data do %>
                    <p class="text-xs text-slate-500">Loading recent activity...</p>
                  <% else %>
                    <%= for account <- @github_accounts do %>
                      <div class="rounded-xl border border-purple-100 bg-white p-4">
                        <div class="flex items-center justify-between">
                          <p class="text-sm font-semibold text-slate-900"><%= account.username %></p>
                          <a
                            href={account.repo_url}
                            class="btn btn-ghost btn-xs"
                          >
                            Profile
                          </a>
                        </div>

                        <div class="mt-4">
                          <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Recent events</p>
                          <%= if account.events == [] do %>
                            <p class="mt-2 text-xs text-slate-500">No recent events.</p>
                          <% else %>
                            <ul class="mt-2 space-y-2 text-xs text-slate-600">
                              <%= for event <- account.events do %>
                                <li class="flex items-center justify-between gap-2">
                                  <span>
                                    <span class="font-semibold text-slate-700"><%= event.type %></span>
                                    <span class="text-slate-400">·</span>
                                    <a href={event.repo_url} class="text-purple-600 hover:text-purple-700">
                                      <%= event.repo %>
                                    </a>
                                  </span>
                                  <span class="text-slate-400"><%= event.created_at %></span>
                                </li>
                              <% end %>
                            </ul>
                          <% end %>
                        </div>
                      </div>
                    <% end %>
                  <% end %>
                </div>
              </div>
            </div>
            <aside class="lg:sticky lg:top-24">
              <div class="rounded-2xl border border-purple-100 bg-white/80 p-6 shadow-sm">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">News</p>
                    <h3 class="mt-1 text-lg font-semibold text-slate-900">Best of the day</h3>
                    <p class="mt-1 text-xs text-slate-500">
                      Live from
                      <a
                        href="https://news.ycombinator.com"
                        class="font-medium text-purple-600"
                      >
                        Hacker News
                      </a>
                    </p>
                  </div>
                </div>

                <div class="mt-6">
                  <%= if @loading_data do %>
                    <p class="text-xs text-slate-500">Loading stories...</p>
                  <% else %>
                    <%= if @news_items == [] do %>
                      <p class="text-xs text-slate-500">No recent stories available.</p>
                    <% else %>
                      <ul class="space-y-3 text-sm text-slate-600">
                        <%= for story <- @news_items do %>
                          <li class="fx-item rounded-xl border border-transparent p-1 transition-colors hover:border-purple-100">
                            <a
                              href={story.url}
                              class="fx-trigger"
                              target="_blank"
                              rel="noreferrer"
                            >
                              <span class="line-clamp-2 text-left font-semibold"><%= story.title %></span>
                            </a>

                            <div class="fx-preview">
                              <div class="fx-preview-content">
                                <p class="text-[10px] font-semibold uppercase tracking-[0.14em] text-purple-500">
                                  Story details
                                </p>

                                <p class="mt-2 text-sm font-semibold leading-snug text-slate-900">
                                  <%= story.title %>
                                </p>

                                <div class="mt-3 flex flex-wrap items-center gap-2 text-xs text-slate-600">
                                  <span class="fx-stamp"><%= story.age %></span>
                                  <span><%= story.score %> points</span>
                                  <span>·</span>
                                  <span><%= story.comments %> comments</span>
                                  <span>·</span>
                                  <span>by <%= story.author %></span>
                                </div>

                                <div class="mt-4 flex flex-wrap items-center gap-3 text-xs">
                                  <a
                                    href={story.url}
                                    class="btn btn-secondary btn-xs"
                                    target="_blank"
                                    rel="noreferrer"
                                  >
                                    Open article
                                  </a>
                                  <a
                                    href={story.hn_url}
                                    class="btn btn-secondary btn-xs"
                                    target="_blank"
                                    rel="noreferrer"
                                  >
                                    Hacker News thread
                                  </a>
                                </div>
                              </div>
                            </div>
                          </li>
                        <% end %>
                      </ul>
                    <% end %>
                  <% end %>
                </div>
              </div>
            </aside>
          </div>
        </section>

        <section id="links" class="mx-auto max-w-6xl px-6 pb-16">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-3">
              <h2 class="text-2xl font-semibold text-slate-900">Quick links</h2>
              <span class="badge-status badge-wip">
                WIP
              </span>
            </div>
          </div>
          <div class="mt-8 grid gap-3 md:grid-cols-2">
            <%= for item <- quick_link_items() do %>
              <div class="fx-item rounded-xl border border-transparent p-1 transition-colors hover:border-purple-100">
                <a href={item.href} class="fx-trigger rounded-xl px-4 py-3">
                  <div class="flex items-center justify-between gap-4">
                    <div>
                      <h3 class="text-sm font-semibold text-slate-900"><%= item.title %></h3>
                      <p class="mt-1 text-xs text-slate-600"><%= item.description %></p>
                    </div>
                    <span class="inline-flex shrink-0 items-center gap-1 text-xs font-semibold text-purple-600">
                      Open
                      <.icon name="hero-arrow-right" class="h-3.5 w-3.5" />
                    </span>
                  </div>
                </a>
              </div>
            <% end %>
          </div>
        </section>

        <section id="week" class="mx-auto max-w-6xl px-6 pb-16">
          <div class="rounded-2xl border border-purple-100 bg-white/80 p-8">
            <div class="flex items-center gap-3">
              <h2 class="text-2xl font-semibold text-slate-900">This week</h2>
              <span class="badge-status badge-wip">
                WIP
              </span>
            </div>
            <div class="mt-6">
              <div class="grid gap-8 lg:grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)]">
                <div class="lg:pr-8">
                  <div class="flex items-center gap-3">
                    <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">
                      Development changelog
                    </p>
                    <span class="badge-status badge-new">
                      New
                    </span>
                  </div>
                  <ul class="mt-4 space-y-3 text-sm text-slate-700">
                    <%= for {label, entries} <- grouped_dev_changelog_items() do %>
                      <li class="fx-item rounded-xl border border-transparent p-1 transition-colors hover:border-purple-100">
                        <button type="button" class="fx-trigger">
                          <span class="text-left font-semibold text-slate-900"><%= label %></span>
                        </button>

                        <div class="fx-preview">
                          <div class="fx-preview-content">
                            <p class="text-[10px] font-semibold uppercase tracking-[0.14em] text-purple-500">
                              <%= label %>
                            </p>
                            <ul class="mt-3 space-y-3 text-xs text-slate-600">
                              <%= for entry <- entries do %>
                                <li>
                                  <p class="font-semibold text-slate-900"><%= entry.title %></p>
                                  <p class="mt-1"><%= entry.detail %></p>
                                </li>
                              <% end %>
                            </ul>
                          </div>
                        </div>
                      </li>
                    <% end %>
                  </ul>
                </div>

                <div class="lg:border-l lg:border-purple-100/80 lg:pl-8">
                <div class="flex items-center gap-3">
                  <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">
                    Week stats
                  </p>
                  <span class="badge-status badge-wip">
                    WIP
                  </span>
                  </div>
                  <div class="mt-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
                    <%= for item <- week_items() do %>
                      <div class="rounded-xl border border-purple-100 bg-white/70 px-4 py-3">
                        <p class="text-2xl font-semibold text-slate-900"><%= item.value %></p>
                        <p class="text-sm text-slate-600"><%= item.title %></p>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

      </main>

      <footer class="border-t border-purple-100 bg-white/70 backdrop-blur">
        <div class="mx-auto flex max-w-6xl flex-col gap-3 px-6 py-5 text-sm text-slate-500 md:flex-row md:items-center md:justify-between">
          <div class="flex flex-wrap gap-3">
            <a href="#links" class="fx-nav-link">Quick links</a>
            <a href={~p"/contributions"} class="fx-nav-link">Contributions</a>
            <a href={~p"/resources"} class="fx-nav-link">Resources</a>
            <a href="#week" class="fx-nav-link">This week</a>
          </div>
          <!-- <div class="flex items-center gap-2">
            <span class="inline-flex items-center rounded-full border border-amber-200 bg-amber-100 px-2 py-1 text-[10px] font-semibold uppercase tracking-wide text-amber-700">
              WIP
            </span>
            <p>© IziHub</p>
          </div> -->
        </div>
      </footer>
    </div>
    </Layouts.app>
    """
  end

  defp quick_link_items do
    [
      %{title: "Profile", description: "Open experience, stack, and CV.", href: "/profile"},
      %{
        title: "Notebooks",
        description: "Browse notebook markdown previews.",
        href: "/notebooks"
      },
      %{
        title: "Contributions",
        description: "View GitHub charts and stats.",
        href: "/contributions"
      },
      %{title: "Resources", description: "Check playbooks and templates.", href: "/resources"}
    ]
  end

  defp dev_changelog_items do
    updates =
      site_update_items() ++
        cv_update_item()

    updates
    |> Enum.reject(&is_nil/1)
    |> Enum.take(5)
  end

  defp grouped_dev_changelog_items do
    {order, grouped} =
      Enum.reduce(dev_changelog_items(), {[], %{}}, fn item, {order, grouped} ->
        label = item.label

        order =
          if Map.has_key?(grouped, label) do
            order
          else
            [label | order]
          end

        grouped = Map.update(grouped, label, [item], &[item | &1])
        {order, grouped}
      end)

    order
    |> Enum.reverse()
    |> Enum.map(fn label -> {label, grouped |> Map.fetch!(label) |> Enum.reverse()} end)
  end

  defp week_items do
    [
      %{
        slug: "tasks",
        title: "Open tasks",
        value: "10",
        detail: "Active tasks currently tracked."
      },
      %{
        slug: "releases",
        title: "Key releases",
        value: "3",
        detail: "Milestones shipped this week."
      },
      %{
        slug: "contribs",
        title: "Contributions",
        value: "4",
        detail: "Notable contributions across active repos."
      }
    ]
  end

  defp site_update_items do
    [
      %{
        label: "UI Improvements",
        title: "UI components upgrade: hover-preview interactions",
        detail: "News and profile cards now share one preview-at-a-time interactions."
      },
      %{
        label: "UI Improvements",
        title: "Unified interaction styling",
        detail: "Cards and CTAs now share the same glow and state tokens across the hub."
      }
    ]
  end

  defp cv_update_item do
    case cv_updated_on() do
      {:ok, date} ->
        [
          %{
            label: "Asset",
            title: "CV udate",
            detail: "Last Updated on #{Date.to_iso8601(date)}."
          }
        ]

      :error ->
        []
    end
  end

  defp cv_updated_on do
    path = Path.join(:code.priv_dir(:core), "static/maxly_garcia_cv.pdf")

    with {:ok, stat} <- File.stat(path),
         {:ok, date} <- mtime_to_date(stat.mtime) do
      {:ok, date}
    else
      _ -> :error
    end
  end

  defp mtime_to_date({{year, month, day}, _time}) do
    Date.new(year, month, day)
  end

  defp mtime_to_date(seconds) when is_integer(seconds) do
    case DateTime.from_unix(seconds) do
      {:ok, datetime} -> {:ok, DateTime.to_date(datetime)}
      _ -> :error
    end
  end

  defp mtime_to_date(_), do: :error

  defp online_count do
    @presence_topic
    |> Presence.list()
    |> map_size()
  end

  defp presence_key do
    "anon-" <> Integer.to_string(System.unique_integer([:positive]))
  end

  defp now_unix do
    System.system_time(:second)
  end
end

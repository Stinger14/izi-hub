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
        <div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
          <div class="text-lg font-semibold text-purple-600 tracking-tight">IziHub</div>
          <nav class="hidden items-center gap-6 text-sm text-slate-600 md:flex">
            <a href="#links" class="hover:text-purple-600">Quick links</a>
            <a href="#contributions" class="hover:text-purple-600">Contributions</a>
            <a href="#resources" class="hover:text-purple-600">Resources</a>
            <a href="#week" class="hover:text-purple-600">This week</a>
          </nav>
          <div class="flex items-center gap-3">
            <div class="hidden items-center gap-2 rounded-full border border-purple-100 bg-white/80 px-3 py-1 text-xs font-medium text-slate-500 md:flex">
              <span class="h-2 w-2 rounded-full bg-emerald-400"></span>
              <span><%= @online_count %> online</span>
            </div>
            <span class="inline-flex items-center rounded-full border border-amber-200 bg-amber-100 px-2 py-1 text-[10px] font-semibold uppercase tracking-wide text-amber-700">
                WIP
            </span>
            <a
              href={~p"/liveapps"}
              class="rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-purple-400"
            >
              Liveapps
            </a>
          </div>
        </div>
      </header>

      <main>
        <section class="mx-auto max-w-6xl px-6 pb-16 pt-16">
          <div class="grid items-start gap-12 lg:grid-cols-[minmax(0,1fr)_340px]">
            <div>
              <p class="text-sm font-medium text-purple-600">Home</p>
              <h1 class="mt-3 text-4xl font-semibold tracking-tight text-slate-900 sm:text-5xl">
                Hi, I’m Maxly García — software developer.
              </h1>
              <p class="mt-4 text-lg text-slate-600">
                I build practical, reliable systems and tools to make things simple.
              </p>
              <div class="mt-8 flex flex-wrap items-center gap-4">
                <a
                  href={~p"/profile"}
                  class="rounded-lg bg-slate-900 px-5 py-3 text-sm font-medium text-white hover:bg-purple-400"
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
                  <a href="https://github.com" class="text-xs font-medium text-purple-600 hover:text-purple-700">
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
                            class="text-xs font-medium text-purple-600 hover:text-purple-700"
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
                  </div>
                  <a
                    href="https://news.ycombinator.com"
                    class="text-xs font-medium text-purple-600 hover:text-purple-700"
                  >
                    Hacker News
                  </a>
                </div>

                <div class="mt-6">
                  <%= if @loading_data do %>
                    <p class="text-xs text-slate-500">Loading stories...</p>
                  <% else %>
                    <%= if @news_items == [] do %>
                      <p class="text-xs text-slate-500">No recent stories available.</p>
                    <% else %>
                      <ul class="space-y-4 text-sm text-slate-600">
                        <%= for story <- @news_items do %>
                          <li class="space-y-1">
                            <a
                              href={story.url}
                              class="font-semibold text-slate-800 hover:text-purple-600"
                              target="_blank"
                              rel="noreferrer"
                            >
                              <%= story.title %>
                            </a>
                            <div class="flex flex-wrap items-center gap-2 text-xs text-slate-500">
                              <span><%= story.score %> points</span>
                              <span>·</span>
                              <a
                                href={story.hn_url}
                                class="text-purple-600 hover:text-purple-700"
                                target="_blank"
                                rel="noreferrer"
                              >
                                <%= story.comments %> comments
                              </a>
                              <span>·</span>
                              <span>by <%= story.author %></span>
                              <span>·</span>
                              <span><%= story.age %></span>
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
              <span class="inline-flex items-center rounded-full border border-amber-200 bg-amber-100 px-2 py-1 text-[10px] font-semibold uppercase tracking-wide text-amber-700">
                WIP
              </span>
            </div>
            <a href="#" class="text-sm font-medium text-purple-600 hover:text-purple-700">View all</a>
          </div>
          <div class="mt-8 grid gap-6 md:grid-cols-2 lg:grid-cols-4">
            <a href="#" class="rounded-2xl border border-purple-100 bg-white/80 hover:border-purple-600 p-6">
              <h3 class="text-base font-semibold text-slate-900">Blog</h3>
              <p class="mt-2 text-sm text-slate-600">Writing and updates.</p>
            </a>
            <a href={~p"/notebooks"} class="rounded-2xl border border-purple-100 bg-white/80 hover:border-purple-600 p-6">
              <h3 class="text-base font-semibold text-slate-900">Notebooks</h3>
              <p class="mt-2 text-sm text-slate-600">Preview notebook markdown.</p>
            </a>
            <a href="#" class="rounded-2xl border border-purple-100 bg-white/80 hover:border-purple-600 p-6">
              <h3 class="text-base font-semibold text-slate-900">News</h3>
              <p class="mt-2 text-sm text-slate-600">Latest notes and announcements.</p>
            </a>
            <a href="#" class="rounded-2xl border border-purple-100 bg-white/80 hover:border-purple-600 p-6">
              <h3 class="text-base font-semibold text-slate-900">Tools</h3>
              <p class="mt-2 text-sm text-slate-600">Utilities and internal helpers.</p>
            </a>
          </div>
        </section>

        <section id="contributions" class="mx-auto max-w-6xl px-6 pb-16">
          <div class="flex items-center justify-between">
            <h2 class="text-2xl font-semibold text-slate-900">GitHub contributions</h2>
            <a href="https://github.com" class="text-sm font-medium text-purple-600 hover:text-purple-700">
              View GitHub
            </a>
          </div>
          <div class="mt-8 grid gap-6 md:grid-cols-2">
            <%= for account <- @github_accounts do %>
              <div class="rounded-2xl border border-purple-100 bg-white/80 p-6">
                <div class="flex items-center justify-between">
                  <h3 class="text-base font-semibold text-slate-900"><%= account.username %></h3>
                  <a
                    href={account.repo_url}
                    class="text-xs font-medium text-purple-600 hover:text-purple-700"
                  >
                    Profile
                  </a>
                </div>
                <div class="mt-4 space-y-4">
                  <div class="overflow-x-auto rounded-xl border border-purple-100 bg-white p-3">
                    <img
                      src={"https://ghchart.rshah.org/#{account.username}"}
                      alt={"GitHub contributions for #{account.username}"}
                      class="h-28 w-full object-cover"
                      loading="lazy"
                    />
                  </div>
                  <div
                    id={"stats-#{String.downcase(account.username)}"}
                    phx-hook="StatsFallback"
                    class="overflow-x-auto rounded-xl border border-purple-100 bg-white p-3"
                  >
                    <div data-stats-fallback class="hidden text-xs text-amber-700">
                      <div class="flex items-center gap-2">
                        <.icon name="hero-exclamation-triangle" class="h-4 w-4 text-amber-500" />
                        <span>Origin server unavailable. Try again later.</span>
                      </div>
                    </div>
                    <div data-stats-content>
                      <%= Phoenix.HTML.raw(render_markdown(stats_markdown(account.username))) %>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </section>

        <section id="resources" class="mx-auto max-w-6xl px-6 pb-16">
          <div class="flex items-center gap-3">
            <h2 class="text-2xl font-semibold text-slate-900">Resources</h2>
            <span class="inline-flex items-center rounded-full border border-amber-200 bg-amber-100 px-2 py-1 text-[10px] font-semibold uppercase tracking-wide text-amber-700">
              WIP
            </span>
          </div>
          <div class="mt-8 grid gap-6 md:grid-cols-2">
            <div class="rounded-2xl border border-purple-100 bg-white/80 p-6">
              <h3 class="text-base font-semibold text-slate-900">Playbooks</h3>
              <p class="mt-2 text-sm text-slate-600">Guides for support, ops, and customer success.</p>
            </div>
            <div class="rounded-2xl border border-purple-100 bg-white/80 p-6">
              <h3 class="text-base font-semibold text-slate-900">Templates</h3>
              <p class="mt-2 text-sm text-slate-600">Reusable docs for briefs and checklists.</p>
            </div>
          </div>
        </section>

        <section id="week" class="mx-auto max-w-6xl px-6 pb-16">
          <div class="rounded-2xl border border-purple-100 bg-white/80 p-8">
            <div class="flex items-center gap-3">
              <h2 class="text-2xl font-semibold text-slate-900">This week</h2>
              <span class="inline-flex items-center rounded-full border border-amber-200 bg-amber-100 px-2 py-1 text-[10px] font-semibold uppercase tracking-wide text-amber-700">
                WIP
              </span>
            </div>
            <div class="mt-6 grid gap-6 md:grid-cols-3">
              <div>
                <p class="text-2xl font-semibold text-slate-900">10</p>
                <p class="text-sm text-slate-600">Open tasks</p>
              </div>
              <div>
                <p class="text-2xl font-semibold text-slate-900">3</p>
                <p class="text-sm text-slate-600">Key releases</p>
              </div>
              <div>
                <p class="text-2xl font-semibold text-slate-900">4</p>
                <p class="text-sm text-slate-600">Contributions</p>
              </div>
            </div>
          </div>
        </section>

      </main>

      <footer class="border-t border-purple-100 bg-white/70 backdrop-blur">
        <div class="mx-auto flex max-w-6xl flex-col gap-4 px-6 py-10 text-sm text-slate-500 md:flex-row md:items-center md:justify-between">
          <div class="flex flex-wrap gap-4">
            <a href="#links" class="hover:text-slate-900">Quick links</a>
            <a href="#contributions" class="hover:text-slate-900">Contributions</a>
            <a href="#resources" class="hover:text-slate-900">Resources</a>
            <a href="#week" class="hover:text-slate-900">This week</a>
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

  defp stats_markdown(username) do
    "[![#{username}'s GitHub stats](https://github-readme-stats.vercel.app/api?username=#{username}&show_icons=true&hide_title=true)](https://github.com/anuraghazra/github-readme-stats)"
  end

  defp render_markdown(md) do
    case Earmark.as_html(md) do
      {:ok, html, _} -> html
      {:error, html, _} -> html
    end
  end

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

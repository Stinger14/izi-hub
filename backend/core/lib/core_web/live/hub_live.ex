defmodule CoreWeb.HubLive do
  use CoreWeb, :live_view

  alias Core.GitHub
  alias Core.HackerNews

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign(
        github_accounts: [],
        news_items: [],
        loading_data: false,
        selected_roadmap_era: roadmap_default_era(),
        show_roadmap_evidence: false
      )

    socket =
      if connected?(socket) do
        send(self(), :load_hub_data)

        assign(socket, loading_data: true)
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

  def handle_event("select_roadmap_chapter", %{"era" => era}, socket) do
    {:noreply, assign(socket, selected_roadmap_era: era, show_roadmap_evidence: false)}
  end

  def handle_event("toggle_roadmap_evidence", _params, socket) do
    {:noreply, update(socket, :show_roadmap_evidence, &(!&1))}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
    <div class="relative min-h-screen bg-purple-50 text-slate-900">
      <%= if is_nil(@current_scope) do %>
        <button
          type="button"
          class="hidden fixed inset-0 z-60 bg-purple-200/35 backdrop-blur-[2px]"
          data-auth-backdrop
          data-auth-close
          aria-label="Close authentication panel"
        >
        </button>
      <% end %>
      <header class="relative z-70 border-b border-purple-100 bg-white/70 backdrop-blur">
        <div class="mx-auto max-w-6xl px-6 py-5">
          <div class="flex items-center justify-between gap-4">
            <nav class="hidden items-center gap-4 text-sm text-slate-600 md:ml-12 md:flex">
              <a href="#links" class="fx-nav-link">Quick links</a>
              <a href={~p"/contributions"} class="fx-nav-link">Contributions</a>
              <a
                href={~p"/resources"}
                class="fx-nav-link fx-nav-link-with-badge relative inline-flex items-center"
              >
                <span>Resources</span>
                <span
                  class="pointer-events-none absolute -right-4 -top-2 badge-status badge-wip badge-compact-64"
                  aria-hidden="true"
                >
                  WIP
                </span>
              </a>
              <a href="#roadmap" class="fx-nav-link">Roadmap</a>
              <a href={~p"/liveapps"} class="fx-nav-link fx-nav-link-with-badge relative inline-flex items-center">
                <span>Liveapps</span>
                <span
                  class="pointer-events-none absolute -right-4 -top-2 badge-status badge-wip badge-compact-64"
                  aria-hidden="true"
                >
                  WIP
                </span>
              </a>
            </nav>
            <%= if is_nil(@current_scope) do %>
              <div class="relative flex items-center gap-2" data-auth-inline>
                <button
                  type="button"
                  class="fx-nav-link inline-flex items-center rounded-md px-2 py-1 text-xs font-semibold"
                  data-auth-toggle="login"
                >
                  Login
                </button>
                <button
                  type="button"
                  class="fx-nav-link inline-flex items-center rounded-md px-2 py-1 text-xs font-semibold"
                  data-auth-toggle="signup"
                >
                  Signup
                </button>

                <div class="hidden absolute right-0 top-full z-80 mt-3 w-[min(24rem,calc(100vw-2rem))]" data-auth-shell>
                  <div class="rounded-2xl border border-purple-100 bg-white p-4 shadow-xl ring-1 ring-purple-200/80">
                    <div>
                      <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Account access</p>
                      <p class="mt-1 text-sm font-semibold text-slate-900">
                        Sign in or create an account
                      </p>
                    </div>

                    <div class="hidden mt-4 border-t border-purple-100/80 pt-4" data-auth-panel="login">
                      <div class="mb-3 flex items-center justify-between">
                        <p class="text-sm font-semibold text-slate-900">Sign in</p>
                        <button type="button" class="btn btn-ghost btn-xs" data-auth-close>
                          <.icon name="hero-x-mark" class="h-4 w-4" />
                        </button>
                      </div>
                      <.form for={%{}} as={:user} action={~p"/login"} method="post" class="space-y-3">
                        <div>
                          <label for="hub-login-email" class="mb-1 block text-xs font-medium text-slate-700">
                            Email
                          </label>
                          <input
                            id="hub-login-email"
                            name="user[email]"
                            type="email"
                            required
                            autocomplete="email"
                            class="w-full rounded-lg border border-purple-100 bg-white px-3 py-2 text-sm focus:border-purple-400 focus:outline-none"
                          />
                        </div>
                        <div>
                          <label for="hub-login-password" class="mb-1 block text-xs font-medium text-slate-700">
                            Password
                          </label>
                          <input
                            id="hub-login-password"
                            name="user[password]"
                            type="password"
                            required
                            autocomplete="current-password"
                            class="w-full rounded-lg border border-purple-100 bg-white px-3 py-2 text-sm focus:border-purple-400 focus:outline-none"
                          />
                        </div>
                        <button type="submit" class="btn btn-primary btn-xs w-full">Sign in</button>
                      </.form>
                    </div>

                    <div class="hidden mt-4 border-t border-purple-100/80 pt-4" data-auth-panel="signup">
                      <div class="mb-3 flex items-center justify-between">
                        <p class="text-sm font-semibold text-slate-900">Create account</p>
                        <button type="button" class="btn btn-ghost btn-xs" data-auth-close>
                          <.icon name="hero-x-mark" class="h-4 w-4" />
                        </button>
                      </div>
                      <.form for={%{}} as={:user} action={~p"/signup"} method="post" class="space-y-3">
                        <div>
                          <label for="hub-signup-email" class="mb-1 block text-xs font-medium text-slate-700">
                            Email
                          </label>
                          <input
                            id="hub-signup-email"
                            name="user[email]"
                            type="email"
                            required
                            autocomplete="email"
                            class="w-full rounded-lg border border-purple-100 bg-white px-3 py-2 text-sm focus:border-purple-400 focus:outline-none"
                          />
                        </div>
                        <p class="text-[11px] text-slate-500">
                          We'll generate a username and send you to password setup.
                        </p>
                        <button type="submit" class="btn btn-primary btn-xs w-full">Continue</button>
                      </.form>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
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
                              <span class="line-clamp-2 text-left font-semibold text-slate-900"><%= story.title %></span>
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

        <section id="roadmap" class="mx-auto max-w-6xl px-6 pb-16">
          <div class="rounded-2xl border border-purple-100 bg-white/80 p-8">
          <div class="flex items-center gap-3">
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">
              Roadmap
            </p>
          </div>
            <div class="flex items-center gap-3">
              <h2 class="text-2xl font-semibold text-slate-900">IziHub evolution</h2>
            </div>
            <div class="mt-6">
              <div class="grid gap-8 lg:grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)]">
                <div class="lg:pr-8">
                  <p class="mt-2 text-xs text-slate-500">
                    History
                  </p>
                  <ul class="mt-4 space-y-2 text-sm text-slate-600">
                    <%= for chapter <- roadmap_chapters() do %>
                      <li>
                        <button
                          type="button"
                          phx-click="select_roadmap_chapter"
                          phx-value-era={chapter.era}
                          class={
                            "w-full rounded-lg border px-3.5 py-2.5 text-left transition-colors " <>
                              if(@selected_roadmap_era == chapter.era,
                                do:
                                  "border-purple-300 bg-purple-50/80 shadow-[0_10px_20px_-18px_rgba(109,40,217,0.55)]",
                                else: "border-purple-100 bg-white/80 hover:bg-purple-50/60"
                              )
                          }
                        >
                          <div class="flex flex-wrap items-center justify-between gap-2">
                            <p class="text-[13px] font-semibold text-slate-900"><%= chapter.era %></p>
                            <span class="text-[10px] font-medium text-purple-600"><%= chapter.range %></span>
                          </div>
                          <div class="mt-1.5 flex flex-wrap items-center gap-1.5">
                            <span class={roadmap_lane_class(chapter.lane)}><%= chapter.lane %></span>
                            <span class="text-[11px] text-slate-600"><%= chapter.story %></span>
                          </div>
                        </button>
                      </li>
                    <% end %>
                  </ul>
                </div>

                <% selected_chapter = selected_roadmap_chapter(@selected_roadmap_era) %>
                <div class="lg:border-l lg:border-purple-100/80 lg:pl-8">
                  <div class="rounded-xl border border-purple-100 bg-white/85 p-4 shadow-sm">
                    <div class="flex flex-wrap items-center justify-between gap-2">
                      <div class="flex flex-wrap items-center gap-2">
                        <p class="text-sm font-semibold text-slate-900"><%= selected_chapter.era %></p>
                        <span class={roadmap_lane_class(selected_chapter.lane)}>
                          <%= selected_chapter.lane %>
                        </span>
                      </div>
                      <span class="text-[11px] font-medium text-purple-600"><%= selected_chapter.range %></span>
                    </div>
                    <p class="mt-2 text-xs text-slate-600"><%= selected_chapter.story %></p>
                    <ul class="mt-3 space-y-1.5 text-xs text-slate-600">
                      <%= for highlight <- selected_chapter.highlights do %>
                        <li><span class="text-purple-500">•</span> <%= highlight %></li>
                      <% end %>
                    </ul>
                    <div class="mt-4 flex items-center justify-between gap-2">
                      <p class="text-[11px] font-medium uppercase tracking-wide text-slate-500">Commits</p>
                      <button
                        type="button"
                        phx-click="toggle_roadmap_evidence"
                        class="btn btn-ghost btn-xs"
                      >
                        <%= if @show_roadmap_evidence do %>
                          Hide commits
                        <% else %>
                          Commits (<%= length(selected_chapter.commits) %>)
                        <% end %>
                      </button>
                    </div>
                    <%= if @show_roadmap_evidence do %>
                      <div class="mt-2 flex flex-wrap gap-1.5">
                        <%= for commit <- selected_chapter.commits do %>
                          <span class="rounded-full border border-purple-100 bg-white px-2 py-1 text-[10px] font-semibold uppercase tracking-wide text-slate-500">
                            <%= commit %>
                          </span>
                        <% end %>
                      </div>
                    <% end %>
                  </div>

                  <div class="mt-4 rounded-xl border border-purple-100 bg-white/85 p-4 shadow-sm">
                    <div class="flex items-center justify-between gap-2">
                      <p class="text-sm font-semibold text-slate-900">Upcoming features</p>
                      <span class={roadmap_lane_class("Current")}>Planned</span>
                    </div>
                    <ul class="mt-3 space-y-2">
                      <%= for {feature, index} <- Enum.with_index(upcoming_feature_items(), 1) do %>
                        <li class="rounded-lg border border-purple-100 bg-white/80 px-3 py-2">
                          <p class="text-[13px] font-semibold text-slate-900">
                            <%= "#{index}. #{feature.title}" %>
                          </p>
                          <p class="mt-1 text-[11px] text-slate-600"><%= feature.detail %></p>
                        </li>
                      <% end %>
                    </ul>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

      </main>

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

  defp roadmap_chapters do
    [
      %{
        era: "Genesis",
        lane: "Core",
        range: "2025-12-03 to 2025-12-12",
        story: "Core platform bootstrapped with first auth and account primitives.",
        highlights: [
          "Phoenix app initialized and base project structure created.",
          "Accounts context introduced with users and token models.",
          "Registration and early account management flow enabled."
        ],
        commits: ["d2a4527", "701ed61", "f9989c2", "6bd86fd", "2ad0959"]
      },
      %{
        era: "Domain Expansion",
        lane: "Product",
        range: "2025-12-18 to 2026-01-01",
        story: "IziHub expanded into multiple product domains and analytics.",
        highlights: [
          "Portfolio, blog, notifications, and finance contexts were added.",
          "Configuration setup was hardened for multi-environment use.",
          "Analytics context was created as the observability foundation."
        ],
        commits: ["13aec00", "841e4b6", "02c0ebc", "4ffe6f7", "083126a"]
      },
      %{
        era: "LiveView Platform Shift",
        lane: "Platform",
        range: "2026-01-28 to 2026-02-02",
        story: "The product shifted to a LiveView-first web architecture.",
        highlights: [
          "Assets, layouts, and root template workflow were established.",
          "Browser pipeline and verified routes integration were completed.",
          "Tailwind and PubSub were enabled for interactive UI behavior."
        ],
        commits: ["cfb7a3f", "ba7f9fb", "1613142", "76fa576", "14eaedd"]
      },
      %{
        era: "User Surfaces v1",
        lane: "UX",
        range: "2026-02-05 to 2026-02-10",
        story: "The first complete user-facing IziHub surfaces came online.",
        highlights: [
          "Profile experience and CV download flow were launched.",
          "Notebook markdown rendering and local preview support were added.",
          "LiveApps module and Hub integrations were introduced."
        ],
        commits: ["8eb324e", "3ca2abd", "dc52900", "58611ea", "db941d3"]
      },
      %{
        era: "UX System & Navigation",
        lane: "UX",
        range: "2026-02-11 to 2026-02-17",
        story: "Visual language and routing were unified across the hub.",
        highlights: [
          "Hub UI was refined with shared interaction components and tokens.",
          "Information architecture moved to /hub and /welcome routing.",
          "Contributions and Resources pages were split into dedicated views."
        ],
        commits: ["f80b432", "5720414", "b73d988", "3c39dd3", "95310eb"]
      },
      %{
        era: "Operations & Metrics",
        lane: "Ops",
        range: "2026-02-14 to 2026-02-20",
        story: "Deployment readiness and admin observability matured.",
        highlights: [
          "Docker and deployment workflows were standardized.",
          "Presence and online activity tracking were integrated.",
          "Admin dashboard and CV download analytics were added."
        ],
        commits: ["aceaa43", "0ef0d47", "f5d5e9c", "9efbc0e"]
      },
      %{
        era: "Current Branch (Unreleased)",
        lane: "Current",
        range: "2026-02-20 to 2026-02-23",
        story: "Auth UX and consistency were tightened across the product.",
        highlights: [
          "Inline Hub login/signup flow replaced separate auth pages.",
          "Email-only signup and password setup onboarding were implemented.",
          "Presence scope and header styling were normalized across pages."
        ],
        commits: ["working-tree"]
      }
    ]
  end

  defp upcoming_feature_items do
    [
      %{
        title: "Personal finance liveapp",
        detail: "Track income, expenses, and category summaries."
      },
      %{
        title: "Resources content",
        detail: "Add practical playbooks, templates, and curated notes."
      },
      %{title: "IziTools", detail: "Ship focused utility tools directly in the hub."}
    ]
  end

  defp roadmap_default_era do
    roadmap_chapters()
    |> List.first()
    |> Map.fetch!(:era)
  end

  defp selected_roadmap_chapter(era) do
    chapters = roadmap_chapters()

    Enum.find(chapters, fn chapter -> chapter.era == era end) || List.first(chapters)
  end

  defp roadmap_lane_class("Core") do
    "inline-flex items-center rounded-full border border-purple-200 bg-purple-50 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-purple-600"
  end

  defp roadmap_lane_class("Product") do
    "inline-flex items-center rounded-full border border-sky-200 bg-sky-50 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-sky-600"
  end

  defp roadmap_lane_class("Platform") do
    "inline-flex items-center rounded-full border border-indigo-200 bg-indigo-50 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-indigo-600"
  end

  defp roadmap_lane_class("UX") do
    "inline-flex items-center rounded-full border border-fuchsia-200 bg-fuchsia-50 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-fuchsia-600"
  end

  defp roadmap_lane_class("Ops") do
    "inline-flex items-center rounded-full border border-emerald-200 bg-emerald-50 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-emerald-600"
  end

  defp roadmap_lane_class("Current") do
    "inline-flex items-center rounded-full border border-amber-200 bg-amber-50 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-amber-600"
  end

  defp roadmap_lane_class(_lane) do
    "inline-flex items-center rounded-full border border-slate-200 bg-slate-50 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-slate-600"
  end
end

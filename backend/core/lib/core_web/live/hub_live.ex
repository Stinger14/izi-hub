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
        loading_data: false
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
end

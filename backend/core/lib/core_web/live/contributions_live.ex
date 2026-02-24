defmodule CoreWeb.ContributionsLive do
  use CoreWeb, :live_view

  alias Core.GitHub

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign(
        github_accounts: [],
        loading_data: false
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

    {:noreply, assign(socket, github_accounts: github_accounts, loading_data: false)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-purple-50 text-slate-900">
        <header class="border-b border-purple-100 bg-white/70 backdrop-blur">
          <div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
            <div>
              <p class="text-lg font-semibold tracking-tight text-purple-500">Contributions</p>
            </div>
            <a href={~p"/hub"} class="btn btn-secondary btn-sm">Back to hub</a>
          </div>
        </header>

        <main class="mx-auto max-w-6xl px-6 pb-16 pt-12">
          <section>
            <p class="text-sm font-medium text-purple-600">Activity overview</p>
            <h1 class="mt-3 text-3xl font-semibold tracking-tight text-slate-900 sm:text-4xl">
              GitHub contribution details
            </h1>
            <p class="mt-3 text-sm text-slate-600">
              Charts and stats for tracked accounts, separated from Hub to keep the home surface focused.
            </p>
          </section>

          <section class="mt-10">
            <div class="flex items-center justify-between">
              <h2 class="text-2xl font-semibold text-slate-900">Tracked accounts</h2>
              <a href="https://github.com" class="btn btn-secondary btn-sm">View GitHub</a>
            </div>

            <%= if @loading_data and @github_accounts == [] do %>
              <p class="mt-6 text-sm text-slate-500">Loading contribution charts...</p>
            <% else %>
              <%= if @github_accounts == [] do %>
                <p class="mt-6 text-sm text-slate-500">No GitHub accounts loaded.</p>
              <% else %>
                <div class="mt-8 grid gap-6 md:grid-cols-2">
                  <%= for account <- @github_accounts do %>
                    <div class="rounded-2xl border border-purple-100 bg-white/80 p-6">
                      <div class="flex items-center justify-between">
                        <h3 class="text-base font-semibold text-slate-900"><%= account.username %></h3>
                        <a href={account.repo_url} class="btn btn-ghost btn-xs">Profile</a>
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
              <% end %>
            <% end %>
          </section>
        </main>
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
end

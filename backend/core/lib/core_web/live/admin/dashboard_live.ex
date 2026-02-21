defmodule CoreWeb.Admin.DashboardLive do
  use CoreWeb, :live_view

  alias Core.Accounts
  alias Core.Analytics
  alias CoreWeb.Presence

  @presence_topic "site:presence"
  @cv_download_path "/cv/download"

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(current_scope: nil)
      |> assign_metrics()

    socket =
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Core.PubSub, @presence_topic)
        socket
      else
        socket
      end

    {:ok, socket}
  end

  def handle_event("refresh", _params, socket) do
    {:noreply, assign_metrics(socket)}
  end

  def handle_info(%{event: "presence_diff"}, socket) do
    {:noreply, assign(socket, online_count: online_count())}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-slate-50 text-slate-900">
        <header class="border-b border-slate-200 bg-white">
          <div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">IziHub</p>
              <h1 class="text-2xl font-semibold tracking-tight">Admin dashboard</h1>
              <p class="mt-1 text-xs text-slate-500">Last refresh: <%= format_datetime(@last_refreshed_at) %></p>
            </div>
            <div class="flex items-center gap-3">
              <button phx-click="refresh" class="btn btn-secondary btn-sm">Refresh</button>
              <a href={~p"/hub"} class="btn btn-secondary btn-sm">Back to hub</a>
            </div>
          </div>
        </header>

        <main class="mx-auto max-w-6xl px-6 py-10">
          <section class="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
            <div class="rounded-2xl border border-slate-200 bg-white p-5">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">CV Downloads</p>
              <p class="mt-3 text-3xl font-semibold"><%= @cv_downloads_total %></p>
              <p class="mt-1 text-xs text-slate-500">Total tracked via <code>/cv</code></p>
            </div>

            <div class="rounded-2xl border border-slate-200 bg-white p-5">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">CV Downloads (7d)</p>
              <p class="mt-3 text-3xl font-semibold"><%= @cv_downloads_7d %></p>
              <p class="mt-1 text-xs text-slate-500">Last 7 days</p>
            </div>

            <div class="rounded-2xl border border-slate-200 bg-white p-5">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">Unique CV Sessions (30d)</p>
              <p class="mt-3 text-3xl font-semibold"><%= @cv_unique_sessions_30d %></p>
              <p class="mt-1 text-xs text-slate-500">Distinct session IDs</p>
            </div>

            <div class="rounded-2xl border border-slate-200 bg-white p-5">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">Online Now</p>
              <p class="mt-3 text-3xl font-semibold"><%= @online_count %></p>
              <p class="mt-1 text-xs text-slate-500">Presence topic: <code>site:presence</code></p>
            </div>
          </section>

          <section class="mt-8 grid gap-4 lg:grid-cols-2">
            <div class="rounded-2xl border border-slate-200 bg-white p-5">
              <div class="flex items-center justify-between">
                <h2 class="text-lg font-semibold">CV download activity</h2>
                <a href={~p"/cv"} class="btn btn-secondary btn-xs">Test download</a>
              </div>
              <div class="mt-4 grid gap-3 sm:grid-cols-2">
                <div class="rounded-xl border border-slate-100 bg-slate-50 p-3">
                  <p class="text-xs text-slate-500">Last 30 days</p>
                  <p class="mt-1 text-xl font-semibold"><%= @cv_downloads_30d %></p>
                </div>
                <div class="rounded-xl border border-slate-100 bg-slate-50 p-3">
                  <p class="text-xs text-slate-500">Last download</p>
                  <p class="mt-1 text-sm font-medium text-slate-700"><%= format_datetime(@cv_last_downloaded_at) %></p>
                </div>
              </div>
            </div>

            <div class="rounded-2xl border border-slate-200 bg-white p-5">
              <h2 class="text-lg font-semibold">User snapshot</h2>
              <div class="mt-4 grid gap-3 sm:grid-cols-2">
                <div class="rounded-xl border border-slate-100 bg-slate-50 p-3">
                  <p class="text-xs text-slate-500">Total users</p>
                  <p class="mt-1 text-xl font-semibold"><%= @total_users %></p>
                </div>
                <div class="rounded-xl border border-slate-100 bg-slate-50 p-3">
                  <p class="text-xs text-slate-500">Active users</p>
                  <p class="mt-1 text-xl font-semibold"><%= @active_users %></p>
                </div>
              </div>
            </div>
          </section>

          <section class="mt-8 grid gap-4 lg:grid-cols-2">
            <div class="rounded-2xl border border-slate-200 bg-white p-5">
              <h2 class="text-lg font-semibold">Top pages (30d)</h2>
              <%= if @top_pages_30d == [] do %>
                <p class="mt-4 text-sm text-slate-500">No page view data yet.</p>
              <% else %>
                <ul class="mt-4 space-y-2">
                  <%= for page <- @top_pages_30d do %>
                    <li class="flex items-center justify-between rounded-xl border border-slate-100 bg-slate-50 px-3 py-2">
                      <span class="truncate pr-2 text-sm text-slate-700"><%= page.page_path %></span>
                      <span class="text-sm font-semibold text-slate-900"><%= page.views %></span>
                    </li>
                  <% end %>
                </ul>
              <% end %>
            </div>

            <div class="rounded-2xl border border-slate-200 bg-white p-5">
              <h2 class="text-lg font-semibold">Recent users</h2>
              <%= if @recent_users == [] do %>
                <p class="mt-4 text-sm text-slate-500">No users found.</p>
              <% else %>
                <ul class="mt-4 space-y-2">
                  <%= for user <- @recent_users do %>
                    <li class="rounded-xl border border-slate-100 bg-slate-50 px-3 py-2">
                      <div class="flex items-center justify-between gap-3">
                        <p class="text-sm font-medium text-slate-900"><%= user.username %></p>
                        <span class="text-xs uppercase tracking-wide text-slate-500"><%= user.role %></span>
                      </div>
                      <p class="mt-1 text-xs text-slate-500"><%= user.email %></p>
                      <p class="mt-1 text-xs text-slate-500">
                        Joined: <%= format_datetime(user.inserted_at) %> |
                        Active: <%= user.is_active %>
                      </p>
                    </li>
                  <% end %>
                </ul>
              <% end %>
            </div>
          </section>
        </main>
      </div>
    </Layouts.app>
    """
  end

  defp assign_metrics(socket) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    seven_days_ago = NaiveDateTime.add(now, -7 * 24 * 60 * 60, :second)
    thirty_days_ago = NaiveDateTime.add(now, -30 * 24 * 60 * 60, :second)

    assign(socket,
      cv_downloads_total: Analytics.count_page_views(@cv_download_path),
      cv_downloads_7d: Analytics.count_page_views(@cv_download_path, seven_days_ago, now),
      cv_downloads_30d: Analytics.count_page_views(@cv_download_path, thirty_days_ago, now),
      cv_unique_sessions_30d:
        Analytics.count_unique_page_sessions(@cv_download_path, thirty_days_ago, now),
      cv_last_downloaded_at: Analytics.last_page_viewed_at(@cv_download_path),
      online_count: online_count(),
      total_users: Accounts.count_users(),
      active_users: Accounts.count_active_users(),
      recent_users: Accounts.list_recent_users(5),
      top_pages_30d: Analytics.get_top_pages(5, thirty_days_ago, now),
      last_refreshed_at: now
    )
  end

  defp online_count do
    @presence_topic
    |> Presence.list()
    |> map_size()
  end

  defp format_datetime(nil), do: "N/A"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end
end

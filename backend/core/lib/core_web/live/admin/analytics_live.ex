defmodule CoreWeb.Admin.AnalyticsLive do
  use CoreWeb, :live_view

  alias Core.Accounts.UsernameGenerator
  alias Core.Analytics
  alias CoreWeb.Presence

  @presence_topic "site:presence"

  def mount(_params, _session, socket) do
    socket = assign_metrics(socket)

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
    {:noreply, assign(socket, :online_now, online_now())}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-purple-50 text-slate-900">
        <header class="border-b border-purple-100 bg-white/70 backdrop-blur">
          <div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
            <div>
              <p class="text-lg font-semibold tracking-tight text-purple-500">Analytics</p>
              <p class="mt-1 text-xs text-slate-500">
                Anonymous visitor activity sourced from tracked page-view records.
              </p>
            </div>
            <div class="flex items-center gap-3">
              <button type="button" phx-click="refresh" class="btn btn-secondary btn-sm">
                Refresh
              </button>
              <a href={~p"/admin"} class="btn btn-secondary btn-sm">Back to dashboard</a>
            </div>
          </div>
        </header>

        <main class="mx-auto max-w-6xl px-6 py-10">
          <section class="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
            <div class="rounded-2xl border border-purple-100 bg-white/80 p-5 shadow-sm">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">Events (30d)</p>
              <p class="mt-3 text-3xl font-semibold"><%= @page_views_30d %></p>
              <p class="mt-1 text-xs text-slate-500">Tracked page-view records</p>
            </div>

            <div class="rounded-2xl border border-purple-100 bg-white/80 p-5 shadow-sm">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">Unique Visitors (30d)</p>
              <p class="mt-3 text-3xl font-semibold"><%= @unique_sessions_30d %></p>
              <p class="mt-1 text-xs text-slate-500">Distinct anonymous session IDs</p>
            </div>

            <div class="rounded-2xl border border-purple-100 bg-white/80 p-5 shadow-sm">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">Online Now</p>
              <p class="mt-3 text-3xl font-semibold"><%= @online_now %></p>
              <p class="mt-1 text-xs text-slate-500">LiveView presence connections</p>
            </div>

            <div class="rounded-2xl border border-purple-100 bg-white/80 p-5 shadow-sm">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">Last Event</p>
              <p class="mt-3 text-sm font-semibold text-slate-900"><%= format_datetime(@last_seen_at) %></p>
              <p class="mt-1 text-xs text-slate-500">Most recent tracked page view</p>
            </div>
          </section>

          <section class="mt-8 grid gap-4 lg:grid-cols-3">
            <div class="rounded-2xl border border-purple-100 bg-white/80 p-5 shadow-sm">
              <h2 class="text-lg font-semibold">Top pages (30d)</h2>
              <%= if @top_pages == [] do %>
                <p class="mt-4 text-sm text-slate-500">No page-view data yet.</p>
              <% else %>
                <ul class="mt-4 space-y-2">
                  <%= for page <- @top_pages do %>
                    <li class="flex items-center justify-between rounded-xl border border-purple-100 bg-white px-3 py-2">
                      <span class="truncate pr-2 text-sm text-slate-700"><%= page.page_path %></span>
                      <span class="text-sm font-semibold text-slate-900"><%= page.views %></span>
                    </li>
                  <% end %>
                </ul>
              <% end %>
            </div>

            <div class="rounded-2xl border border-purple-100 bg-white/80 p-5 shadow-sm">
              <h2 class="text-lg font-semibold">Devices (30d)</h2>
              <%= if @devices == [] do %>
                <p class="mt-4 text-sm text-slate-500">No device data yet.</p>
              <% else %>
                <ul class="mt-4 space-y-2">
                  <%= for device <- @devices do %>
                    <li class="flex items-center justify-between rounded-xl border border-purple-100 bg-white px-3 py-2">
                      <span class="text-sm capitalize text-slate-700"><%= device.device_type || "unknown" %></span>
                      <span class="text-sm font-semibold text-slate-900"><%= device.count %></span>
                    </li>
                  <% end %>
                </ul>
              <% end %>
            </div>

            <div class="rounded-2xl border border-purple-100 bg-white/80 p-5 shadow-sm">
              <h2 class="text-lg font-semibold">Locations (30d)</h2>
              <%= if @locations == [] do %>
                <p class="mt-4 text-sm text-slate-500">No location data yet.</p>
              <% else %>
                <ul class="mt-4 space-y-2">
                  <%= for location <- @locations do %>
                    <li class="flex items-center justify-between rounded-xl border border-purple-100 bg-white px-3 py-2">
                      <span class="truncate pr-2 text-sm text-slate-700">
                        <%= format_location(location.city, location.country) %>
                      </span>
                      <span class="text-sm font-semibold text-slate-900"><%= location.count %></span>
                    </li>
                  <% end %>
                </ul>
              <% end %>
            </div>
          </section>

          <section class="mt-8 rounded-2xl border border-purple-100 bg-white/80 p-5 shadow-sm">
            <div class="flex items-center justify-between gap-3">
              <div>
                <h2 class="text-lg font-semibold">Recent visitor activity</h2>
                <p class="mt-1 text-xs text-slate-500">
                  Display labels are stable anonymous aliases derived from the session ID.
                </p>
              </div>
              <p class="text-xs text-slate-500">Last refresh: <%= format_datetime(@last_refreshed_at) %></p>
            </div>

            <%= if @recent_page_views == [] do %>
              <p class="mt-4 text-sm text-slate-500">No tracked page-view activity yet.</p>
            <% else %>
              <div class="mt-4 overflow-x-auto">
                <table class="min-w-full divide-y divide-purple-100 text-left text-sm">
                  <thead>
                    <tr class="text-xs uppercase tracking-wide text-slate-500">
                      <th class="px-3 py-2 font-medium">Visitor</th>
                      <th class="px-3 py-2 font-medium">Page</th>
                      <th class="px-3 py-2 font-medium">Context</th>
                      <th class="px-3 py-2 font-medium">Referrer</th>
                      <th class="px-3 py-2 font-medium">Seen</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-purple-50">
                    <%= for page_view <- @recent_page_views do %>
                      <tr>
                        <td class="px-3 py-3 align-top">
                          <p class="font-medium text-slate-900"><%= visitor_label(page_view.session_id) %></p>
                          <p class="mt-1 text-xs text-slate-500">
                            <%= format_location(page_view.city, page_view.country) %>
                          </p>
                        </td>
                        <td class="px-3 py-3 align-top text-slate-700"><%= page_view.page_path %></td>
                        <td class="px-3 py-3 align-top text-slate-700">
                          <%= format_context(page_view.browser, page_view.os, page_view.device_type) %>
                        </td>
                        <td class="px-3 py-3 align-top text-slate-700"><%= format_referrer(page_view.referrer) %></td>
                        <td class="px-3 py-3 align-top text-slate-700"><%= format_datetime(page_view.inserted_at) %></td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
          </section>
        </main>
      </div>
    </Layouts.app>
    """
  end

  defp assign_metrics(socket) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    thirty_days_ago = NaiveDateTime.add(now, -30 * 24 * 60 * 60, :second)

    assign(socket,
      page_views_30d: Analytics.count_page_views(nil, thirty_days_ago, now),
      unique_sessions_30d: Analytics.count_unique_sessions(thirty_days_ago, now),
      online_now: online_now(),
      last_seen_at: Analytics.last_page_viewed_at(),
      top_pages: Analytics.get_top_pages(5, thirty_days_ago, now),
      devices: Analytics.get_devices_breakdown(thirty_days_ago, now),
      locations: Analytics.get_geographic_distribution(thirty_days_ago, now) |> Enum.take(5),
      recent_page_views: Analytics.list_recent_page_views(limit: 25),
      last_refreshed_at: now
    )
  end

  defp online_now do
    @presence_topic
    |> Presence.list()
    |> map_size()
  end

  defp visitor_label(nil), do: "Guest unknown"

  defp visitor_label(session_id) do
    "Guest " <> UsernameGenerator.generate_from_value(session_id)
  end

  defp format_context(browser, os, device_type) do
    parts =
      [browser, os, device_type]
      |> Enum.filter(&present?/1)

    case parts do
      [] -> "Unknown context"
      _ -> Enum.join(parts, " / ")
    end
  end

  defp format_location(city, country) do
    parts =
      [city, country]
      |> Enum.filter(&present?/1)

    case parts do
      [] -> "Unknown location"
      _ -> Enum.join(parts, ", ")
    end
  end

  defp format_referrer(nil), do: "Direct / unknown"
  defp format_referrer(""), do: "Direct / unknown"

  defp format_referrer(referrer) do
    case URI.parse(referrer) do
      %URI{host: host} when is_binary(host) and host != "" -> host
      _ -> referrer
    end
  end

  defp format_datetime(nil), do: "N/A"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp present?(value), do: is_binary(value) and String.trim(value) != ""
end

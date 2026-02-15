defmodule CoreWeb.LiveAppsLive do
  use CoreWeb, :live_view

  alias Core.Notebooks

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       current_scope: nil,
       apps: [],
       error: nil
     )}
  end

  def handle_params(_params, _uri, socket) do
    case Notebooks.list_livebook_apps() do
      {:ok, apps} ->
        {:noreply, assign(socket, apps: apps, error: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, apps: [], error: inspect(reason))}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-purple-50 text-slate-900">
        <header class="border-b border-purple-100 bg-white/70 backdrop-blur">
          <div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide text-purple-500">Apps</p>
              <p class="text-lg font-semibold tracking-tight text-slate-900">Live Apps</p>
            </div>
            <a
              href={~p"/hub"}
              class="rounded-lg border border-purple-100 bg-white px-4 py-2 text-sm font-medium text-slate-700 transition-colors hover:bg-purple-300"
            >
              Back home
            </a>
          </div>
        </header>

        <main class="mx-auto max-w-6xl px-6 pb-16 pt-12">
          <div class="flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">
            <div>
              <p class="text-sm font-medium text-purple-600">Live apps</p>
              <h1 class="mt-3 text-3xl font-semibold tracking-tight text-slate-900 sm:text-4xl">
                Open your deployed apps
              </h1>
              <p class="mt-3 text-sm text-slate-600">
                Apps are discovered from local <code>.livemd</code> files and link to your hosted Livebook service.
              </p>
            </div>
            <div class="flex flex-wrap items-center gap-3">
              <a
                href={~p"/liveapps"}
                class="rounded-lg border border-purple-100 bg-white px-4 py-2 text-sm font-medium text-slate-700 transition-colors hover:bg-purple-300"
              >
                Refresh apps
              </a>
            </div>
          </div>

          <%= if @error do %>
            <div class="mt-6 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">
              <%= @error %>
            </div>
          <% end %>

          <%= if Enum.empty?(@apps) do %>
            <div class="mt-10 rounded-2xl border border-purple-100 bg-white/80 px-6 py-8 text-sm text-slate-600">
              No Livebook apps found in <span class="font-semibold text-slate-700">priv/notebooks</span>.
            </div>
          <% else %>
            <div class="mt-10 grid gap-6 md:grid-cols-2">
              <%= for app <- @apps do %>
                <%= if app.url do %>
                  <a
                    href={app.url}
                    class="rounded-2xl border border-purple-100 bg-white/80 p-6 text-left shadow-sm hover:border-purple-200"
                    target="_blank"
                    rel="noreferrer"
                  >
                    <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Live app</p>
                    <p class="mt-2 text-lg font-semibold text-slate-900"><%= app.title %></p>
                    <p class="mt-2 text-sm text-slate-600"><%= app.description %></p>
                  </a>
                <% else %>
                  <div class="rounded-2xl border border-dashed border-purple-100 bg-white/80 p-6 text-left text-slate-600">
                    <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Live app</p>
                    <p class="mt-2 text-lg font-semibold text-slate-900"><%= app.title %></p>
                    <p class="mt-2 text-sm text-slate-600"><%= app.description %></p>
                    <p class="mt-3 text-xs text-amber-600">App URL not configured.</p>
                  </div>
                <% end %>
              <% end %>
            </div>
          <% end %>

          <div class="mt-6 text-xs text-slate-500">
            Source: local <span class="font-semibold text-slate-700">priv/notebooks/*.livemd</span>
          </div>
        </main>
      </div>
    </Layouts.app>
    """
  end
end

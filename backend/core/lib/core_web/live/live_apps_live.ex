defmodule CoreWeb.LiveAppsLive do
  use CoreWeb, :live_view

  alias Core.Notebooks

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:current_scope, fn -> nil end)
     |> assign(
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
      <div class="min-h-screen">
        <header class="border-b border-[color:var(--hub-border)]">
          <div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
            <div>
              <p class="font-display text-lg text-[var(--hub-accent-2)]">Live Apps</p>
            </div>
            <a
              href={~p"/hub"}
              class="btn btn-secondary btn-sm"
            >
              Back home
            </a>
          </div>
        </header>

        <main class="mx-auto max-w-6xl px-6 pb-16 pt-12">
          <div class="flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">
            <div>
              <h1 class="font-display mt-3 text-3xl text-[var(--hub-text)] sm:text-4xl">
                Deployed LiveBook apps
              </h1>
            </div>
            <div class="flex flex-wrap items-center gap-3">
              <a
                href={~p"/liveapps"}
                class="btn btn-secondary btn-sm"
              >
                Refresh apps
              </a>
            </div>
          </div>

          <%= if @error do %>
            <div class={["mt-6 rounded-2xl border border-[color:var(--tone-expense)]/30 px-4 py-3 text-sm", CoreWeb.FinanceComponents.tone_class("expense", :soft)]}>
              <%= @error %>
            </div>
          <% end %>

          <%= if Enum.empty?(@apps) do %>
            <div class="hub-glass mt-10 rounded-2xl px-6 py-8 text-sm text-[var(--hub-muted)]">
              No Livebook apps found in <span class="font-semibold text-[var(--hub-text)]">priv/notebooks</span>.
            </div>
          <% else %>
            <div class="mt-10 grid gap-6 md:grid-cols-2">
              <%= for app <- @apps do %>
                <%= if app.url do %>
                  <div class="fx-item rounded-2xl border border-transparent p-1 transition-colors hover:border-[color:var(--hub-border)]">
                    <a
                      href={app.url}
                      class="fx-trigger rounded-2xl p-6"
                      target="_blank"
                      rel="noreferrer"
                    >
                      <p class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--hub-accent-2)]">Live app</p>
                      <p class="mt-2 text-lg font-semibold text-[var(--hub-text)]"><%= app.title %></p>
                      <p class="mt-2 text-sm text-[var(--hub-muted)]"><%= app.description %></p>
                    </a>
                  </div>
                <% else %>
                  <div class="rounded-2xl border border-dashed border-[color:var(--hub-border)] bg-[var(--hub-surface)] p-6 text-left text-[var(--hub-muted)]">
                    <p class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--hub-accent-2)]">Live app</p>
                    <p class="mt-2 text-lg font-semibold text-[var(--hub-text)]"><%= app.title %></p>
                    <p class="mt-2 text-sm text-[var(--hub-muted)]"><%= app.description %></p>
                    <p class={["mt-3 text-xs", CoreWeb.FinanceComponents.tone_class("review", :text)]}>App URL not configured.</p>
                  </div>
                <% end %>
              <% end %>
            </div>
          <% end %>

          <div class="mt-6 text-xs text-[var(--hub-muted)]">
            Source: local <span class="font-semibold text-[var(--hub-text)]">priv/notebooks/*.livemd</span>
          </div>
        </main>
      </div>
    </Layouts.app>
    """
  end
end

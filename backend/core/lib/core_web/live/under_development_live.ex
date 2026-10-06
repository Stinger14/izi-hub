defmodule CoreWeb.UnderDevelopmentLive do
  use CoreWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign_new(socket, :current_scope, fn -> nil end)}
  end

  def render(assigns) do
    info = feature_info(assigns.live_action)
    visual = feature_visual(assigns.live_action)

    assigns =
      assigns
      |> assign(:info, info)
      |> assign(:visual, visual)

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} theme="hub">
      <div class="relative min-h-screen overflow-hidden">
        <div
          class="pointer-events-none absolute -left-16 top-16 h-64 w-64 rounded-full blur-3xl"
          style="background: radial-gradient(circle, rgba(167,139,250,0.22) 0%, rgba(167,139,250,0) 72%);"
        >
        </div>
        <div
          class="pointer-events-none absolute -right-12 bottom-8 h-72 w-72 rounded-full blur-3xl"
          style="background: radial-gradient(circle, rgba(139,92,246,0.18) 0%, rgba(139,92,246,0) 74%);"
        >
        </div>

        <header class="border-b border-[color:var(--hub-border)]">
          <div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
            <div>
              <p class="font-display text-lg text-[var(--hub-accent-2)]">Under Development</p>
            </div>
            <a href={~p"/hub"} class="btn btn-secondary btn-sm">Back to hub</a>
          </div>
        </header>

        <main class="mx-auto flex min-h-[calc(100vh-8rem)] max-w-4xl items-center px-6 py-12">
          <section class="hub-glass relative w-full rounded-2xl p-8">
            <div class="grid gap-8 lg:grid-cols-[132px_minmax(0,1fr)] lg:items-start">
              <div class="mx-auto w-full max-w-[132px]">
                <div class={@visual.icon_shell_class}>
                  <img
                    src={~p"/images/potion-purple.svg"}
                    alt="Purple potion pouring"
                    class="h-20 w-20 object-contain drop-shadow-[0_8px_10px_rgba(124,58,237,0.24)]"
                  />
                </div>
                <p class={@visual.label_class}><%= @visual.label %></p>
              </div>

              <div>
                <div class="flex flex-wrap items-center gap-2">
                  <h1 class="font-display text-2xl text-[var(--hub-text)]"><%= @info.title %></h1>
                  <span class="badge-status badge-wip">WIP</span>
                </div>
                <p class="mt-3 text-sm text-[var(--hub-muted)]"><%= @info.summary %></p>

                <div class="mt-6 rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-4 py-4">
                  <div class="flex items-center justify-between gap-2">
                    <p class="text-xs font-semibold uppercase tracking-wide text-[var(--hub-muted)]">What's coming</p>
                    <a href={~p"/hub#roadmap"} class="text-xs font-medium text-[var(--hub-secondary)] transition hover:text-[var(--hub-accent-2)]">
                      View roadmap
                    </a>
                  </div>
                  <div class="relative mt-4">
                    <div class="absolute bottom-0 left-[13px] top-1 w-px bg-[color:var(--hub-border)]"></div>
                    <ol class="space-y-3 pl-7 text-sm text-[var(--hub-muted)]">
                      <%= for {item, idx} <- Enum.with_index(@info.next_steps, 1) do %>
                        <li class="relative">
                          <span class="absolute -left-7 top-0.5 inline-flex h-5 w-5 items-center justify-center rounded-full border border-[color:var(--hub-accent)]/40 bg-[color:var(--hub-accent)]/15 text-[10px] font-semibold text-[var(--hub-accent-2)]">
                            <%= idx %>
                          </span>
                          <p><%= item %></p>
                        </li>
                      <% end %>
                    </ol>
                  </div>
                </div>

                <div class="mt-6 flex flex-wrap items-center gap-3">
                  <a href={~p"/hub"} class="btn btn-secondary btn-sm">Back to hub</a>
                  <a href={~p"/hub#roadmap"} class="btn btn-ghost btn-sm">Open roadmap</a>
                </div>
              </div>
            </div>
          </section>
        </main>
      </div>
    </Layouts.app>
    """
  end

  defp feature_info(:resources) do
    %{
      title: "Resources",
      summary: "This section is being prepared with practical content and templates.",
      next_steps: [
        "Curate production-ready playbooks and checklists.",
        "Publish starter templates for common workflows.",
        "Add curated notes linked from roadmap milestones."
      ]
    }
  end

  defp feature_info(:liveapps) do
    %{
      title: "Live Apps",
      summary: "Live app surfaces are paused until the next implementation milestone.",
      next_steps: [
        "Ship personal finance LiveApp MVP.",
        "Harden deployment and environment toggles.",
        "Add usage telemetry for launched apps."
      ]
    }
  end

  defp feature_info(_action) do
    %{
      title: "Feature",
      summary: "This area is currently under development.",
      next_steps: ["Check back soon for updates."]
    }
  end

  defp feature_visual(:resources) do
    %{
      icon_shell_class:
        "mx-auto flex h-24 w-24 items-center justify-center rounded-2xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] shadow-[0_12px_28px_-18px_rgba(139,92,246,0.7)]",
      label_class: "mt-3 text-center text-xs font-medium text-[var(--hub-accent-2)]",
      label: "Resources track"
    }
  end

  defp feature_visual(:liveapps) do
    %{
      icon_shell_class:
        "mx-auto flex h-24 w-24 items-center justify-center rounded-2xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] shadow-[0_12px_28px_-18px_rgba(139,92,246,0.7)]",
      label_class: "mt-3 text-center text-xs font-medium text-[var(--hub-accent-2)]",
      label: "LiveApps track"
    }
  end

  defp feature_visual(_action) do
    %{
      icon_shell_class:
        "mx-auto flex h-24 w-24 items-center justify-center rounded-2xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] shadow-[0_12px_28px_-18px_rgba(139,92,246,0.7)]",
      label_class: "mt-3 text-center text-xs font-medium text-[var(--hub-accent-2)]",
      label: "Active track"
    }
  end
end

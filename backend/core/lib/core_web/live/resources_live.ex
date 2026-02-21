defmodule CoreWeb.ResourcesLive do
  use CoreWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, current_scope: nil)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-purple-50 text-slate-900">
        <header class="border-b border-purple-100 bg-white/70 backdrop-blur">
          <div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide text-purple-500">Library</p>
              <p class="text-lg font-semibold tracking-tight text-slate-900">Resources</p>
            </div>
            <a href={~p"/hub"} class="btn btn-secondary btn-sm">Back to hub</a>
          </div>
        </header>

        <main class="mx-auto max-w-6xl px-6 pb-16 pt-12">
          <section>
            <p class="text-sm font-medium text-purple-600">Operational docs</p>
            <h1 class="mt-3 text-3xl font-semibold tracking-tight text-slate-900 sm:text-4xl">
              Playbooks and templates
            </h1>
            <p class="mt-3 text-sm text-slate-600">
              A focused space for reusable guides, checklists, and delivery templates.
            </p>
          </section>

          <section class="mt-10">
            <div class="flex items-center justify-between">
              <h2 class="text-xl font-semibold text-slate-900">Playbooks</h2>
              <span class="badge-status badge-wip">WIP</span>
            </div>
            <div class="mt-4 grid gap-4 md:grid-cols-2">
              <%= for item <- playbook_items() do %>
                <article class="rounded-xl border border-purple-100 bg-white/80 p-5">
                  <h3 class="text-sm font-semibold text-slate-900"><%= item.title %></h3>
                  <p class="mt-2 text-sm text-slate-600"><%= item.description %></p>
                </article>
              <% end %>
            </div>
          </section>

          <section class="mt-10">
            <div class="flex items-center justify-between">
              <h2 class="text-xl font-semibold text-slate-900">Templates</h2>
              <span class="badge-status badge-wip">WIP</span>
            </div>
            <div class="mt-4 grid gap-4 md:grid-cols-2">
              <%= for item <- template_items() do %>
                <article class="rounded-xl border border-purple-100 bg-white/80 p-5">
                  <h3 class="text-sm font-semibold text-slate-900"><%= item.title %></h3>
                  <p class="mt-2 text-sm text-slate-600"><%= item.description %></p>
                </article>
              <% end %>
            </div>
          </section>
        </main>
      </div>
    </Layouts.app>
    """
  end

  defp playbook_items do
    [
      %{
        title: "Support intake playbook",
        description: "Escalation flow and triage checklist for inbound technical issues."
      },
      %{
        title: "Release coordination playbook",
        description: "Pre-release checks, rollout notes, and rollback decision points."
      }
    ]
  end

  defp template_items do
    [
      %{
        title: "Feature brief template",
        description: "Product scope, constraints, acceptance criteria, and rollout notes."
      },
      %{
        title: "Postmortem template",
        description: "Impact summary, timeline, root cause, and action items."
      }
    ]
  end
end

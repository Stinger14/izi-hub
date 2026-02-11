defmodule CoreWeb.LiveAppsLive do
  use CoreWeb, :live_view

  alias Core.Notebooks

  def mount(_params, _session, socket) do
    {:ok, assign(socket, current_scope: nil, livebook_url: Notebooks.livebook_app_path())}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-purple-50 text-slate-900">
        <header class="border-b border-purple-100 bg-white/70 backdrop-blur">
          <div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide text-purple-500">Apps</p>
              <p class="text-lg font-semibold tracking-tight text-slate-900">Livebook Apps</p>
            </div>
            <a
              href={~p"/"}
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
                Run hosted Livebook apps
              </h1>
              <p class="mt-3 text-sm text-slate-600">
                Apps are ready-to-use workflows deployed from notebooks.
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

          <div class="mt-10 grid gap-6 md:grid-cols-2">
            <div class="rounded-2xl border border-purple-100 bg-white/80 p-6 text-left shadow-sm">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Playground</p>
              <p class="mt-2 text-lg font-semibold text-slate-900">Izi Hub Playground</p>
              <p class="mt-2 text-sm text-slate-600">
                Try the core API workflows through the deployed Livebook app.
              </p>
              <div class="mt-4">
                <a
                  href={@livebook_url}
                  class="inline-flex items-center rounded-lg border border-purple-100 bg-white px-4 py-2 text-sm font-medium text-slate-700 transition-colors hover:bg-purple-300"
                >
                  Open app
                </a>
              </div>
            </div>
          </div>
        </main>
      </div>
    </Layouts.app>
    """
  end
end

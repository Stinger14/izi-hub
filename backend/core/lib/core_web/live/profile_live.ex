defmodule CoreWeb.ProfileLive do
  use CoreWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, current_scope: nil)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-slate-900/40 px-6 py-16">
        <div class="mx-auto flex min-h-[calc(100vh-8rem)] items-center justify-center">
          <div class="w-full max-w-3xl rounded-2xl border border-purple-100 bg-white/90 p-8 shadow-xl backdrop-blur">
            <div class="flex items-center justify-between">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Profile</p>
              <a href={~p"/"} class="text-xs text-purple-600 hover:text-purple-700">Back home</a>
            </div>

            <h1 class="mt-4 text-3xl font-semibold text-slate-900">Maxly García</h1>
            <p class="mt-2 text-sm text-slate-600">
              Software developer focused on pragmatic systems, thoughtful UX, and reliable APIs.
            </p>

            <div class="mt-6 grid gap-6 md:grid-cols-2">
              <div>
                <h2 class="text-sm font-semibold text-slate-900">Focus</h2>
                <p class="mt-2 text-sm text-slate-600">
                  Phoenix LiveView, backend systems, tooling, and product‑grade integrations.
                </p>
              </div>
              <div>
                <h2 class="text-sm font-semibold text-slate-900">Links</h2>
                <div class="mt-2 flex flex-col gap-2 text-sm">
                  <a href="#" class="text-purple-600 hover:text-purple-700">GitHub</a>
                  <a href="#" class="text-purple-600 hover:text-purple-700">LinkedIn</a>
                  <a href="#" class="text-purple-600 hover:text-purple-700">Email</a>
                </div>
              </div>
            </div>

            <div class="mt-8 flex flex-wrap items-center gap-4">
              <a
                href={~p"/maxly_garcia_cv.pdf"}
                download
                class="rounded-lg bg-slate-900 px-5 py-3 text-sm font-medium text-white hover:bg-slate-800"
              >
                Download CV
              </a>
              <a
                href={~p"/"}
                class="rounded-lg border border-purple-100 bg-white px-5 py-3 text-sm font-medium text-slate-700 hover:border-purple-200"
              >
                Back to home
              </a>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end

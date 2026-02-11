defmodule CoreWeb.HubLandingLive do
  use CoreWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, current_scope: nil)}
  end

  # def handle_event("inc", _params, socket) do
  #   {:noreply, update(socket, :count, &(&1 + 1))}
  # end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-purple-50/30 text-slate-900">
        <main>
          <section class="mx-auto max-w-5xl px-6 pb-16 pt-20">
            <div class="grid items-center gap-12 lg:grid-cols-[minmax(0,1fr)_340px]">
              <div>
                <p class="text-sm font-medium text-purple-600">Welcome</p>
                <h1 class="mt-3 text-4xl font-semibold tracking-tight text-slate-900 sm:text-5xl">
                    I design systems that stay out of the way.
                </h1>
                <p class="mt-4 text-lg text-slate-600">
                This hub is where my work, notes, and tools live.
                </p>
                <div class="mt-8 flex flex-wrap items-center gap-4">
                  <a
                    href={~p"/"}
                    class="rounded-lg bg-slate-900 px-5 py-3 text-sm font-medium text-white hover:bg-purple-600"
                  >
                    Enter Hub
                  </a>
                </div>
                <p class="mt-4 text-xs text-slate-500">You’ll find the projects I’m shipping, the experiments I’m testing, and the ideas I’m refining. It’s a living desk.</p>
              </div>
              <div class="rounded-2xl border border-purple-100 bg-white/80 p-6 shadow-sm">
                <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Start here</p>
                <h2 class="mt-2 text-lg font-semibold text-slate-900">Quick orientation</h2>
                <div class="mt-4 space-y-3 text-sm text-slate-600">
                  <div class="flex items-start gap-2">
                    <.icon name="hero-check" class="mt-0.5 h-4 w-4 text-purple-500" />
                    Visit the Hub for the latest updates, links and contributions.
                  </div>
                  <div class="flex items-start gap-2">
                    <.icon name="hero-check" class="mt-0.5 h-4 w-4 text-purple-500" />
                    Open the Profile to download CV.
                  </div>
                  <div class="flex items-start gap-2">
                    <.icon name="hero-check" class="mt-0.5 h-4 w-4 text-purple-500" />
                    Explore Notebooks for notes, pocs and experiments.
                  </div>
                </div>
              </div>
            </div>
          </section>

          <section class="mx-auto max-w-5xl px-6 pb-16">
            <div class="flex items-center justify-between">
              <h2 class="text-2xl font-semibold text-slate-900">What you’ll find</h2>
            </div>
            <div class="mt-8 grid gap-6 md:grid-cols-3">
              <div class="rounded-2xl border border-purple-100 bg-white/80 p-6">
                <h3 class="text-base font-semibold text-slate-900">Hub</h3>
                <p class="mt-2 text-sm text-slate-600">The main dashboard.</p>
              </div>
              <div class="rounded-2xl border border-purple-100 bg-white/80 p-6">
                <h3 class="text-base font-semibold text-slate-900">Profile</h3>
                <p class="mt-2 text-sm text-slate-600">Experience, stack, CV and contact links.</p>
              </div>
              <div class="rounded-2xl border border-purple-100 bg-white/80 p-6">
                <h3 class="text-base font-semibold text-slate-900">Notebooks</h3>
                <p class="mt-2 text-sm text-slate-600">Notes, ideas, and docs.</p>
              </div>
            </div>
          </section>
        </main>

        <footer class="border-t border-purple-100 bg-white/70 backdrop-blur">
          <div class="mx-auto flex max-w-5xl flex-col gap-6 px-6 py-10 text-sm text-slate-500 md:flex-row md:items-center md:justify-between">
            <div class="space-y-2">
              <p class="text-sm font-semibold text-slate-800">
                IziHub <span class="align-super text-[10px] font-semibold text-slate-400">™</span>
              </p>
              <p class="text-xs text-slate-500">
                A calm home for work, notes, and tools.
              </p>
            </div>
            <div class="flex flex-wrap gap-4">
              <a href={~p"/"} class="hover:text-purple-600">Hub</a>
              <a href={~p"/profile"} class="hover:text-purple-600">Profile</a>
              <a href={~p"/notebooks"} class="hover:text-purple-600">Notebooks</a>
              <a href={~p"/liveapps"} class="hover:text-purple-600">Liveapps</a>
            </div>
          </div>
        </footer>
      </div>
    </Layouts.app>
    """
  end
end

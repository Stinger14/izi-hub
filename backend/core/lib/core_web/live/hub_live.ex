defmodule CoreWeb.HubLive do
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
          <div class="text-lg font-semibold tracking-tight">IziHub</div>
          <nav class="hidden items-center gap-6 text-sm text-slate-600 md:flex">
            <a href="#links" class="hover:text-slate-900">Quick links</a>
            <a href="#updates" class="hover:text-slate-900">Updates</a>
            <a href="#resources" class="hover:text-slate-900">Resources</a>
            <a href="#week" class="hover:text-slate-900">This week</a>
          </nav>
          <div class="flex items-center gap-3">
            <a
              href="#open"
              class="rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800"
            >
              Open dashboard
            </a>
          </div>
        </div>
      </header>

      <main>
        <section class="mx-auto max-w-6xl px-6 pb-16 pt-16">
          <div class="grid items-center gap-12 lg:grid-cols-2">
            <div>
              <p class="text-sm font-medium text-purple-600">Home</p>
              <h1 class="mt-3 text-4xl font-semibold tracking-tight text-slate-900 sm:text-5xl">
                Hi, I’m Maxly García — software developer.
              </h1>
              <p class="mt-4 text-lg text-slate-600">
                I build practical, reliable systems and the tooling that keeps teams moving.
              </p>
              <div class="mt-8 flex flex-wrap items-center gap-4">
                <a
                  href={~p"/profile"}
                  class="rounded-lg bg-slate-900 px-5 py-3 text-sm font-medium text-white hover:bg-slate-800"
                >
                  View profile
                </a>
              </div>
            </div>
            <div class="grid gap-4 sm:grid-cols-2">
              <a href="#" class="rounded-2xl border border-purple-100 bg-white/80 p-5 text-left">
                <p class="text-sm font-semibold text-slate-900">Blog</p>
                <p class="mt-1 text-xs text-slate-600">Writing and updates.</p>
              </a>
              <a href={~p"/notebooks"} class="rounded-2xl border border-purple-100 bg-white/80 p-5 text-left">
                <p class="text-sm font-semibold text-slate-900">Notebooks</p>
                <p class="mt-1 text-xs text-slate-600">Try API commands in Livebook.</p>
              </a>
              <a href="#" class="rounded-2xl border border-purple-100 bg-white/80 p-5 text-left">
                <p class="text-sm font-semibold text-slate-900">News</p>
                <p class="mt-1 text-xs text-slate-600">Latest notes and announcements.</p>
              </a>
              <a href="#" class="rounded-2xl border border-purple-100 bg-white/80 p-5 text-left">
                <p class="text-sm font-semibold text-slate-900">Tools</p>
                <p class="mt-1 text-xs text-slate-600">Utilities and internal helpers.</p>
              </a>
            </div>
          </div>
        </section>

        <section id="links" class="mx-auto max-w-6xl px-6 pb-16">
          <div class="flex items-center justify-between">
            <h2 class="text-2xl font-semibold text-slate-900">Quick links</h2>
            <a href="#" class="text-sm font-medium text-purple-600 hover:text-purple-700">View all</a>
          </div>
          <div class="mt-8 grid gap-6 md:grid-cols-3">
            <div class="rounded-2xl border border-purple-100 bg-white/80 p-6">
              <h3 class="text-base font-semibold text-slate-900">Product dashboard</h3>
              <p class="mt-2 text-sm text-slate-600">KPIs, goals, and release health.</p>
            </div>
            <div class="rounded-2xl border border-purple-100 bg-white/80 p-6">
              <h3 class="text-base font-semibold text-slate-900">Design system</h3>
              <p class="mt-2 text-sm text-slate-600">Components, tokens, and guidelines.</p>
            </div>
            <div class="rounded-2xl border border-purple-100 bg-white/80 p-6">
              <h3 class="text-base font-semibold text-slate-900">Support queue</h3>
              <p class="mt-2 text-sm text-slate-600">Daily queue and escalations.</p>
            </div>
          </div>
        </section>

        <section id="updates" class="mx-auto max-w-6xl px-6 pb-16">
          <div class="flex items-center justify-between">
            <h2 class="text-2xl font-semibold text-slate-900">Team updates</h2>
            <a href="#" class="text-sm font-medium text-purple-600 hover:text-purple-700">View all</a>
          </div>
          <div class="mt-8 space-y-4">
            <div class="rounded-2xl border border-purple-100 bg-white/80 p-6">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Product</p>
              <h3 class="mt-2 text-base font-semibold text-slate-900">Release 1.2 shipping Friday</h3>
              <p class="mt-2 text-sm text-slate-600">
                Final QA today. Docs update is in progress.
              </p>
            </div>
            <div class="rounded-2xl border border-purple-100 bg-white/80 p-6">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Operations</p>
              <h3 class="mt-2 text-base font-semibold text-slate-900">Onboarding revamp ready</h3>
              <p class="mt-2 text-sm text-slate-600">
                New checklist and 30‑minute walkthrough for first week.
              </p>
            </div>
          </div>
        </section>

        <section id="resources" class="mx-auto max-w-6xl px-6 pb-16">
          <h2 class="text-2xl font-semibold text-slate-900">Resources</h2>
          <div class="mt-8 grid gap-6 md:grid-cols-2">
            <div class="rounded-2xl border border-purple-100 bg-white/80 p-6">
              <h3 class="text-base font-semibold text-slate-900">Playbooks</h3>
              <p class="mt-2 text-sm text-slate-600">Guides for support, ops, and customer success.</p>
            </div>
            <div class="rounded-2xl border border-purple-100 bg-white/80 p-6">
              <h3 class="text-base font-semibold text-slate-900">Templates</h3>
              <p class="mt-2 text-sm text-slate-600">Reusable docs for briefs and checklists.</p>
            </div>
          </div>
        </section>

        <section id="week" class="mx-auto max-w-6xl px-6 pb-16">
          <div class="rounded-2xl border border-purple-100 bg-white/80 p-8">
            <h2 class="text-2xl font-semibold text-slate-900">This week</h2>
            <div class="mt-6 grid gap-6 md:grid-cols-3">
              <div>
                <p class="text-2xl font-semibold text-slate-900">12</p>
                <p class="text-sm text-slate-600">Open tasks</p>
              </div>
              <div>
                <p class="text-2xl font-semibold text-slate-900">3</p>
                <p class="text-sm text-slate-600">Key releases</p>
              </div>
              <div>
                <p class="text-2xl font-semibold text-slate-900">5</p>
                <p class="text-sm text-slate-600">Team updates</p>
              </div>
            </div>
          </div>
        </section>

        <section id="open" class="border-t border-purple-100 bg-white/70 backdrop-blur">
          <div class="mx-auto max-w-6xl px-6 py-14">
            <div class="flex flex-col items-start justify-between gap-6 md:flex-row md:items-center">
              <div>
                <h2 class="text-2xl font-semibold text-slate-900">Keep your team focused. Keep work moving.</h2>
                <p class="mt-2 text-sm text-slate-600">Bring everything into one calm home.</p>
              </div>
              <div class="flex flex-wrap items-center gap-4">
                <a
                  href="#open"
                  class="rounded-lg bg-slate-900 px-5 py-3 text-sm font-medium text-white hover:bg-slate-800"
                >
                  Open dashboard
                </a>
                <a
                  href="#updates"
                  class="rounded-lg border border-purple-100 bg-white/80 px-5 py-3 text-sm font-medium text-slate-700 hover:border-purple-200"
                >
                  View updates
                </a>
              </div>
            </div>
          </div>
        </section>
      </main>

      <footer class="border-t border-purple-100 bg-white/70 backdrop-blur">
        <div class="mx-auto flex max-w-6xl flex-col gap-4 px-6 py-10 text-sm text-slate-500 md:flex-row md:items-center md:justify-between">
          <div class="flex flex-wrap gap-4">
            <a href="#links" class="hover:text-slate-900">Quick links</a>
            <a href="#updates" class="hover:text-slate-900">Updates</a>
            <a href="#resources" class="hover:text-slate-900">Resources</a>
            <a href="#week" class="hover:text-slate-900">This week</a>
          </div>
          <p>© IziHub</p>
        </div>
      </footer>
    </div>
    </Layouts.app>
    """
  end
end

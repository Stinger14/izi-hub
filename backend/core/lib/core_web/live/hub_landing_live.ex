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
      <div class="bg-white text-slate-900">
        <header class="border-b border-slate-100">
          <div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
            <div class="text-lg font-semibold tracking-tight">IziHub</div>
            <nav class="hidden items-center gap-6 text-sm text-slate-600 md:flex">
              <a href="#product" class="hover:text-slate-900">Product</a>
              <a href="#use-cases" class="hover:text-slate-900">Use Cases</a>
              <a href="#resources" class="hover:text-slate-900">Resources</a>
            </nav>
            <div class="flex items-center gap-3">
              <a
                href="#get-started"
                class="rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800"
              >
                Get started
              </a>
            </div>
          </div>
        </header>

        <main>
          <section class="mx-auto max-w-6xl px-6 pb-16 pt-20">
            <div class="grid items-center gap-12 lg:grid-cols-2">
              <div>
                <p class="text-sm font-medium text-slate-500">A calm hub for team work</p>
                <h1 class="mt-3 text-4xl font-semibold tracking-tight text-slate-900 sm:text-5xl">
                  Your team’s work, organized in one calm hub.
                </h1>
                <p class="mt-4 text-lg text-slate-600">
                  IziHub brings updates, docs, and workflows into a single, fast home—so everyone finds
                  what they need without the clutter.
                </p>
                <div class="mt-8 flex flex-wrap items-center gap-4">
                  <a
                    href="#get-started"
                    class="rounded-lg bg-slate-900 px-5 py-3 text-sm font-medium text-white hover:bg-slate-800"
                  >
                    Get started
                  </a>
                  <a
                    href="#demo"
                    class="rounded-lg border border-slate-200 px-5 py-3 text-sm font-medium text-slate-700 hover:border-slate-300"
                  >
                    View demo
                  </a>
                </div>
                <p class="mt-4 text-xs text-slate-500">Setup in minutes. No credit card required.</p>
              </div>
              <div class="rounded-2xl border border-slate-200 bg-slate-50 p-6">
                <div class="rounded-xl border border-slate-200 bg-white p-5">
                  <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Today</p>
                  <h2 class="mt-2 text-lg font-semibold text-slate-900">Weekly updates</h2>
                  <p class="mt-2 text-sm text-slate-600">
                    Share announcements, project notes, and onboarding steps in a consistent, minimal
                    layout that doesn’t get buried.
                  </p>
                  <div class="mt-4 grid gap-3">
                    <div class="rounded-lg border border-slate-100 bg-slate-50 px-3 py-2 text-xs text-slate-600">
                      Launch checklist
                    </div>
                    <div class="rounded-lg border border-slate-100 bg-slate-50 px-3 py-2 text-xs text-slate-600">
                      New hire guide
                    </div>
                    <div class="rounded-lg border border-slate-100 bg-slate-50 px-3 py-2 text-xs text-slate-600">
                      Ops dashboard
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </section>

          <section class="border-y border-slate-100 bg-slate-50">
            <div class="mx-auto max-w-6xl px-6 py-10 text-center">
              <p class="text-sm font-medium text-slate-500">
                Trusted by product, ops, and support teams that value clarity.
              </p>
              <div class="mt-6 grid grid-cols-2 gap-6 text-xs font-semibold uppercase tracking-wide text-slate-400 sm:grid-cols-5">
                <span>Logo 1</span>
                <span>Logo 2</span>
                <span>Logo 3</span>
                <span>Logo 4</span>
                <span>Logo 5</span>
              </div>
            </div>
          </section>

          <section id="product" class="mx-auto max-w-6xl px-6 py-16">
            <div class="grid gap-8 md:grid-cols-3">
              <div class="rounded-2xl border border-slate-100 p-6">
                <h3 class="text-lg font-semibold text-slate-900">One home for every team</h3>
                <p class="mt-3 text-sm text-slate-600">
                  A clean landing space for updates, links, and key docs.
                </p>
              </div>
              <div class="rounded-2xl border border-slate-100 p-6">
                <h3 class="text-lg font-semibold text-slate-900">Fast, focused navigation</h3>
                <p class="mt-3 text-sm text-slate-600">
                  Smart categories and shortcuts keep everything two clicks away.
                </p>
              </div>
              <div class="rounded-2xl border border-slate-100 p-6">
                <h3 class="text-lg font-semibold text-slate-900">Built for day‑to‑day use</h3>
                <p class="mt-3 text-sm text-slate-600">
                  Lightweight, responsive, and easy to maintain with LiveView.
                </p>
              </div>
            </div>
          </section>

          <section class="mx-auto max-w-6xl px-6 pb-16">
            <div class="grid items-center gap-10 lg:grid-cols-2">
              <div>
                <h2 class="text-2xl font-semibold text-slate-900">
                  Put critical updates where people actually look.
                </h2>
                <p class="mt-3 text-sm text-slate-600">
                  Share announcements, project notes, and onboarding steps in a consistent, minimal
                  layout that doesn’t get buried.
                </p>
                <div class="mt-5 space-y-3">
                  <div class="flex items-center gap-2 text-sm text-slate-600">
                    <.icon name="hero-check" class="h-5 w-5 text-emerald-600" />
                    Pinned announcements
                  </div>
                  <div class="flex items-center gap-2 text-sm text-slate-600">
                    <.icon name="hero-check" class="h-5 w-5 text-emerald-600" />
                    Team‑specific sections
                  </div>
                  <div class="flex items-center gap-2 text-sm text-slate-600">
                    <.icon name="hero-check" class="h-5 w-5 text-emerald-600" />
                    Readable on mobile
                  </div>
                </div>
              </div>
              <div class="aspect-16/10 rounded-2xl border border-slate-200 bg-slate-50"></div>
            </div>
          </section>

          <section class="mx-auto max-w-6xl px-6 pb-16">
            <div class="grid items-center gap-10 lg:grid-cols-2">
              <div class="aspect-16/10 rounded-2xl border border-slate-200 bg-slate-50"></div>
              <div>
                <h2 class="text-2xl font-semibold text-slate-900">
                  Keep links, tools, and docs in one tidy place.
                </h2>
                <p class="mt-3 text-sm text-slate-600">
                  Reduce tab sprawl. Give each team a simple, scannable hub with the essentials.
                </p>
                <div class="mt-5 space-y-3">
                  <div class="flex items-center gap-2 text-sm text-slate-600">
                    <.icon name="hero-check" class="h-5 w-5 text-emerald-600" />
                    Quick links grid
                  </div>
                  <div class="flex items-center gap-2 text-sm text-slate-600">
                    <.icon name="hero-check" class="h-5 w-5 text-emerald-600" />
                    Curated resources
                  </div>
                  <div class="flex items-center gap-2 text-sm text-slate-600">
                    <.icon name="hero-check" class="h-5 w-5 text-emerald-600" />
                    Lightweight search
                  </div>
                </div>
              </div>
            </div>
          </section>

          <section class="border-y border-slate-100 bg-slate-50">
            <div class="mx-auto max-w-6xl px-6 py-16">
              <div class="grid gap-8 md:grid-cols-3">
                <div>
                  <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Step 1</p>
                  <h3 class="mt-2 text-lg font-semibold text-slate-900">Connect your sources</h3>
                  <p class="mt-2 text-sm text-slate-600">Add key links, docs, and updates.</p>
                </div>
                <div>
                  <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Step 2</p>
                  <h3 class="mt-2 text-lg font-semibold text-slate-900">Organize by team</h3>
                  <p class="mt-2 text-sm text-slate-600">Create a clean space for each group.</p>
                </div>
                <div>
                  <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Step 3</p>
                  <h3 class="mt-2 text-lg font-semibold text-slate-900">Launch in minutes</h3>
                  <p class="mt-2 text-sm text-slate-600">Publish once and keep it fresh.</p>
                </div>
              </div>
            </div>
          </section>

          <section id="use-cases" class="mx-auto max-w-6xl px-6 py-16">
            <h2 class="text-2xl font-semibold text-slate-900">Built for everyday use cases</h2>
            <div class="mt-8 grid gap-6 md:grid-cols-3">
              <div class="rounded-2xl border border-slate-100 p-6">
                <h3 class="text-base font-semibold text-slate-900">New hire onboarding</h3>
                <p class="mt-2 text-sm text-slate-600">Give new teammates a focused home from day one.</p>
              </div>
              <div class="rounded-2xl border border-slate-100 p-6">
                <h3 class="text-base font-semibold text-slate-900">Weekly team updates</h3>
                <p class="mt-2 text-sm text-slate-600">Share progress without flooding inboxes.</p>
              </div>
              <div class="rounded-2xl border border-slate-100 p-6">
                <h3 class="text-base font-semibold text-slate-900">Cross‑team resource hub</h3>
                <p class="mt-2 text-sm text-slate-600">Centralize key links and docs across groups.</p>
              </div>
            </div>
          </section>

          <section class="mx-auto max-w-6xl px-6 pb-16">
            <div class="grid gap-6 rounded-2xl border border-slate-100 bg-white p-8 md:grid-cols-3">
              <div>
                <p class="text-2xl font-semibold text-slate-900">2×</p>
                <p class="text-sm text-slate-600">Faster onboarding</p>
              </div>
              <div>
                <p class="text-2xl font-semibold text-slate-900">30%</p>
                <p class="text-sm text-slate-600">Fewer internal pings</p>
              </div>
              <div>
                <p class="text-2xl font-semibold text-slate-900">1</p>
                <p class="text-sm text-slate-600">Place for all essentials</p>
              </div>
            </div>
          </section>

          <section class="mx-auto max-w-6xl px-6 pb-16">
            <div class="rounded-2xl border border-slate-100 bg-slate-50 p-8">
              <blockquote class="text-lg text-slate-700">
                “IziHub is the first page we open every morning. Everything we need is right there.”
              </blockquote>
              <p class="mt-4 text-sm font-semibold text-slate-900">[Name], [Role] at [Company]</p>
            </div>
          </section>

          <section class="mx-auto max-w-6xl px-6 pb-16">
            <h2 class="text-2xl font-semibold text-slate-900">FAQ</h2>
            <div class="mt-8 grid gap-6 md:grid-cols-2">
              <div class="rounded-2xl border border-slate-100 p-6">
                <h3 class="text-base font-semibold text-slate-900">Does this work for multiple teams?</h3>
                <p class="mt-2 text-sm text-slate-600">Yes—each team can have its own focused hub.</p>
              </div>
              <div class="rounded-2xl border border-slate-100 p-6">
                <h3 class="text-base font-semibold text-slate-900">Is it easy to update?</h3>
                <p class="mt-2 text-sm text-slate-600">Updates are quick, and the layout stays consistent.</p>
              </div>
              <div class="rounded-2xl border border-slate-100 p-6">
                <h3 class="text-base font-semibold text-slate-900">Can we start small?</h3>
                <p class="mt-2 text-sm text-slate-600">Start with one team and expand as needed.</p>
              </div>
              <div class="rounded-2xl border border-slate-100 p-6">
                <h3 class="text-base font-semibold text-slate-900">What does it take to launch?</h3>
                <p class="mt-2 text-sm text-slate-600">A quick setup, then you’re live in minutes.</p>
              </div>
            </div>
          </section>

          <section id="get-started" class="border-t border-slate-100 bg-slate-50">
            <div class="mx-auto max-w-6xl px-6 py-16">
              <div class="flex flex-col items-start justify-between gap-6 md:flex-row md:items-center">
                <div>
                  <h2 class="text-2xl font-semibold text-slate-900">A simpler home for your team’s work.</h2>
                  <p class="mt-2 text-sm text-slate-600">
                    Launch a clean, minimal hub in minutes.
                  </p>
                </div>
                <div class="flex flex-wrap items-center gap-4">
                  <a
                    href="#get-started"
                    class="rounded-lg bg-slate-900 px-5 py-3 text-sm font-medium text-white hover:bg-slate-800"
                  >
                    Get started
                  </a>
                  <a
                    href="#demo"
                    class="rounded-lg border border-slate-200 px-5 py-3 text-sm font-medium text-slate-700 hover:border-slate-300"
                  >
                    View demo
                  </a>
                </div>
              </div>
            </div>
          </section>
        </main>

        <footer class="border-t border-slate-100">
          <div class="mx-auto flex max-w-6xl flex-col gap-4 px-6 py-10 text-sm text-slate-500 md:flex-row md:items-center md:justify-between">
            <div class="flex flex-wrap gap-4">
              <a href="#product" class="hover:text-slate-900">Product</a>
              <a href="#use-cases" class="hover:text-slate-900">Use Cases</a>
              <a href="#resources" class="hover:text-slate-900">Docs</a>
              <a href="#" class="hover:text-slate-900">Privacy</a>
              <a href="#" class="hover:text-slate-900">Terms</a>
            </div>
            <p>© IziHub</p>
          </div>
        </footer>
      </div>
    </Layouts.app>
    """
  end
end

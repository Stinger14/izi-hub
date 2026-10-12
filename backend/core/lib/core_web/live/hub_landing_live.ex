defmodule CoreWeb.HubLandingLive do
  use CoreWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign_new(socket, :current_scope, fn -> nil end)}
  end

  # def handle_event("inc", _params, socket) do
  #   {:noreply, update(socket, :count, &(&1 + 1))}
  # end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <main class="max-w-none p-0">
        <section class="mx-auto max-w-5xl px-6 pb-16 pt-20">
          <div class="grid items-center gap-12 lg:grid-cols-[minmax(0,1fr)_340px]">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--hub-accent-2)]">
                Welcome
              </p>
              <h1 class="font-display mt-3 text-5xl leading-[1.05] text-[var(--hub-text)] sm:text-6xl">
                I design systems that <span class="hub-gradient-text">stay out of the way.</span>
              </h1>
              <p class="mt-5 text-lg text-[var(--hub-muted)]">
                You’ll find the projects I’m shipping, the experiments I’m testing, and the ideas I’m refining. It’s a living desk.
              </p>
              <div class="mt-8 flex flex-wrap items-center gap-4">
                <a href={~p"/hub"} class="btn btn-primary btn-glow">Enter Hub</a>
                <a href={~p"/profile"} class="btn btn-secondary btn-glow">Profile &amp; CV</a>
              </div>
              <p class="mt-4 text-xs text-[var(--hub-muted)]">
                This hub is where my work, notes, and tools live.
              </p>
            </div>
            <div class="hub-glass rounded-2xl border border-[color:var(--hub-border)] bg-[var(--hub-card)] p-6 shadow-[0_18px_36px_-26px_var(--hub-shadow)]">
              <p class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--hub-accent-2)]">
                Start here
              </p>
              <h2 class="font-display mt-2 text-2xl text-[var(--hub-text)]">Quick orientation</h2>
              <div class="mt-4 space-y-3 text-sm text-[var(--hub-muted)]">
                <div :for={line <- orientation_lines()} class="flex items-start gap-2">
                  <.icon name="hero-check" class="mt-0.5 h-4 w-4 shrink-0 text-[var(--hub-secondary)]" />
                  <%= line %>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section class="mx-auto max-w-5xl px-6 pb-20">
          <h2 class="font-display text-3xl text-[var(--hub-text)]">What you’ll find</h2>
          <div class="mt-8 grid gap-6 md:grid-cols-3">
            <div
              :for={{title, body} <- highlights()}
              class="hub-glass rounded-2xl border border-[color:var(--hub-border)] bg-[var(--hub-card)] p-6"
            >
              <h3 class="font-display text-xl text-[var(--hub-secondary)]"><%= title %></h3>
              <p class="mt-2 text-sm text-[var(--hub-muted)]"><%= body %></p>
            </div>
          </div>
        </section>
      </main>
    </Layouts.app>
    """
  end

  defp orientation_lines do
    [
      "Visit the Hub for the latest updates, links and contributions.",
      "Visit the Profile to review experience and download the CV.",
      "Explore Notebooks for notes, pocs and experiments."
    ]
  end

  defp highlights do
    [
      {"Hub", "The main dashboard."},
      {"Profile", "Experience, stack, CV and contact links."},
      {"Notebooks", "Notes, ideas, and docs."}
    ]
  end
end

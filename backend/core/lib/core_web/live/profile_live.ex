defmodule CoreWeb.ProfileLive do
  use CoreWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, current_scope: nil, show_full_intro: false)}
  end

  def handle_event("toggle_intro", _params, socket) do
    {:noreply, update(socket, :show_full_intro, &(!&1))}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-purple-100/40 px-6 py-16">
        <div class="mx-auto flex min-h-[calc(100vh-8rem)] items-center justify-center">
          <div class="w-full max-w-3xl rounded-2xl border border-purple-100 bg-white/90 p-8 shadow-xl backdrop-blur">
            <div class="flex items-center justify-between">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Profile</p>
              <a
                href={~p"/"}
                class="rounded-lg border border-purple-100 bg-white px-3 py-1 text-xs font-medium text-slate-700 transition-colors hover:bg-purple-300"
              >
                Back home
              </a>
            </div>

            <div class="mt-6 flex flex-col gap-4 sm:flex-row sm:items-center">
              <div class="relative mx-auto sm:mx-0">
                <div class="h-28 w-28 rounded-full bg-gradient-to-br from-purple-500 via-fuchsia-500 to-indigo-500 p-[3px] shadow-lg shadow-purple-200/70">
                  <img
                    src={~p"/images/pp3.jpeg"}
                    alt="Profile picture of Maxly Garcia"
                    class="h-full w-full rounded-full object-cover ring-4 ring-white"
                  />
                </div>
              </div>
              <div class="text-center sm:text-left">
                <h1 class="text-3xl font-semibold text-slate-900">Maxly García</h1>
                <p class="mt-1 text-sm text-slate-500">Software Engineer</p>
              </div>
            </div>

            <div class="mt-4">
              <p class="text-sm text-slate-600">
                <%= if @show_full_intro do %>
                  Software engineer with over 10 years of experience, formed in OOP with C++/Python transitioned to
                  functional programming leveraging Elixir. Really into microservices, having adeptly developed and
                  implemented critical business unit services and APIs.<br>

                  <br>I'm interested in anything regarding tech and love to try new frameworks. If I'd have to choose my
                  top 3 hobbies they would be: Max | Basketball | Elixir.<br>

                  <br>I am dad to Max and I am very proud of him, he is the best boy I could have ever asked for. I do believe
                    Jesus is Lord and he has taught me to serve and give back, that would be my life's philosophy.

                <% else %>
                  Software engineer with 10+ years building backend systems, APIs, and distributed services.
                <% end %>
              </p>
              <button
                type="button"
                phx-click="toggle_intro"
                class="mt-2 rounded-lg px-3 py-1 text-xs font-semibold text-purple-600 transition-colors hover:bg-purple-300"
              >
                <%= if @show_full_intro, do: "Show less", else: "Read more" %>
              </button>
            </div>

            <div class="mt-6 grid gap-6 md:grid-cols-2">
              <div class="space-y-6">
                <div>
                  <h2 class="text-sm font-semibold text-slate-900">Focus</h2>
                  <p class="mt-2 text-sm text-slate-600">
                    Backend & distributed systems, LiveView, FastAPI, Docker, Kubernetes and product‑grade integrations.
                  </p>
                </div>
                <div class="border-t border-purple-100 pt-4">
                  <h2 class="text-sm font-semibold text-slate-900">Stack</h2>
                  <div class="mt-2 flex flex-wrap gap-2">
                    <span class="inline-flex items-center rounded-full border border-slate-200 bg-slate-100 px-2.5 py-1 text-xs font-medium text-slate-700">
                      Elixir (Phoenix/LiveView)
                    </span>
                    <span class="inline-flex items-center rounded-full border border-slate-200 bg-slate-100 px-2.5 py-1 text-xs font-medium text-slate-700">
                      Python (Django/FastAPI)
                    </span>
                    <span class="inline-flex items-center rounded-full border border-slate-200 bg-slate-100 px-2.5 py-1 text-xs font-medium text-slate-700">
                      Docker
                    </span>
                    <span class="inline-flex items-center rounded-full border border-slate-200 bg-slate-100 px-2.5 py-1 text-xs font-medium text-slate-700">
                      Kubernetes
                    </span>
                    <span class="inline-flex items-center rounded-full border border-slate-200 bg-slate-100 px-2.5 py-1 text-xs font-medium text-slate-700">
                      AWS (S3 Bucket)
                    </span>
                    <span class="inline-flex items-center rounded-full border border-slate-200 bg-slate-100 px-2.5 py-1 text-xs font-medium text-slate-700">
                      GCP
                    </span>
                    <span class="inline-flex items-center rounded-full border border-slate-200 bg-slate-100 px-2.5 py-1 text-xs font-medium text-slate-700">
                      Postgres
                    </span>
                    <span class="inline-flex items-center rounded-full border border-slate-200 bg-slate-100 px-2.5 py-1 text-xs font-medium text-slate-700">
                      Redis
                    </span>
                  </div>
                </div>
              </div>
              <div>
                <div class="rounded-xl border border-purple-100 bg-white/70 p-4 text-sm shadow-sm transition hover:shadow-md">
                  <h2 class="text-sm font-semibold text-slate-900">Contact</h2>
                  <div class="mt-3 flex flex-col gap-2">
                    <a
                      href="mailto:maxgarcia6@gmail.com"
                      class="text-purple-600 hover:text-purple-700"
                    >
                      Email
                    </a>
                    <a
                      href="https://www.linkedin.com/in/maxly-garcia-bb3110129/"
                      class="text-purple-600 hover:text-purple-700"
                    >
                      LinkedIn
                    </a>
                  </div>
                  <div class="mt-4">
                    <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">
                      GitHub Accounts
                    </p>
                    <div class="mt-2 flex flex-col gap-2">
                      <a
                        href="https://github.com/Stinger14"
                        class="text-purple-600 hover:text-purple-700"
                      >
                        Stinger14
                      </a>
                      <a
                        href="https://github.com/ghost1ndshell"
                        class="text-purple-600 hover:text-purple-700"
                      >
                        ghost1ndshell
                      </a>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div class="mt-8">
              <div class="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
                <h2 class="text-sm font-semibold text-slate-900">Books</h2>
                <p class="text-xs text-slate-500">Scroll to explore the full list.</p>
              </div>
              <div id="books-scroll" class="relative mt-3" phx-hook="ScrollHint">
                <div class="flex flex-nowrap gap-2 overflow-x-auto pb-1" data-scroll-container>
                <span
                  title="Fundamentals"
                  class="inline-flex items-center whitespace-nowrap rounded-full border border-amber-200 bg-amber-100 px-3 py-1 text-xs font-medium text-amber-800"
                >
                  Smalltalk Best Practice Patterns
                </span>
                <span
                  title="Python"
                  class="inline-flex items-center whitespace-nowrap rounded-full border border-emerald-200 bg-emerald-100 px-3 py-1 text-xs font-medium text-emerald-800"
                >
                  Django for Professionals
                </span>
                <span
                  title="Fundamentals"
                  class="inline-flex items-center whitespace-nowrap rounded-full border border-amber-200 bg-amber-100 px-3 py-1 text-xs font-medium text-amber-800"
                >
                  Gang of 4
                </span>
                <span
                  title="Fundamentals"
                  class="inline-flex items-center whitespace-nowrap rounded-full border border-amber-200 bg-amber-100 px-3 py-1 text-xs font-medium text-amber-800"
                >
                  The Pragmatic Programmer
                </span>
                <span
                  title="Fundamentals"
                  class="inline-flex items-center whitespace-nowrap rounded-full border border-amber-200 bg-amber-100 px-3 py-1 text-xs font-medium text-amber-800"
                >
                  Clean Code
                </span>
                <span
                  title="Elixir"
                  class="inline-flex items-center whitespace-nowrap rounded-full border border-purple-200 bg-purple-100 px-3 py-1 text-xs font-medium text-purple-800"
                >
                  Elixir in Action
                </span>
                <span
                  title="Fundamentals"
                  class="inline-flex items-center whitespace-nowrap rounded-full border border-amber-200 bg-amber-100 px-3 py-1 text-xs font-medium text-amber-800"
                >
                  The Mythical Man-Month
                </span>
                <span
                  title="Elixir"
                  class="inline-flex items-center whitespace-nowrap rounded-full border border-purple-200 bg-purple-100 px-3 py-1 text-xs font-medium text-purple-800"
                >
                  Programming Phoenix >= 1.4
                </span>
                <span
                  title="Elixir"
                  class="inline-flex items-center whitespace-nowrap rounded-full border border-purple-200 bg-purple-100 px-3 py-1 text-xs font-medium text-purple-800"
                >
                  Programming Elixir >= 1.6
                </span>
                <span
                  title="Database"
                  class="inline-flex items-center whitespace-nowrap rounded-full border border-blue-200 bg-blue-100 px-3 py-1 text-xs font-medium text-blue-800"
                >
                  Programming Ecto
                </span>
                <span
                  title="Fundamentals"
                  class="inline-flex items-center whitespace-nowrap rounded-full border border-amber-200 bg-amber-100 px-3 py-1 text-xs font-medium text-amber-800"
                >
                  Cracking the Coding Interview
                </span>
              </div>
                <div data-scroll-hint
                class="pointer-events-none absolute right-2 top-2 rounded-full bg-slate-900/70 px-2 py-1 text-[10px] uppercase tracking-wide text-white
                  opacity-0 transition">Scroll</div>
                  <div class="pointer-events-none absolute inset-y-0 right-0 w-12 bg-gradient-to-l from-white/95 to-transparent"></div>
                  </div>
              <div class="mt-3 flex flex-wrap items-center gap-3 text-xs text-slate-500">
                <span class="inline-flex items-center gap-2">
                  <span class="h-2 w-2 rounded-full bg-amber-300"></span>
                  Fundamentals
                </span>
                <span class="inline-flex items-center gap-2">
                  <span class="h-2 w-2 rounded-full bg-purple-300"></span>
                  Elixir
                </span>
                <span class="inline-flex items-center gap-2">
                  <span class="h-2 w-2 rounded-full bg-emerald-300"></span>
                  Python
                </span>
                <span class="inline-flex items-center gap-2">
                  <span class="h-2 w-2 rounded-full bg-blue-300"></span>
                  Database
                </span>
              </div>
            </div>

            <div class="mt-8 flex flex-wrap items-center gap-4">
              <a
                href={~p"/maxly_garcia_cv.pdf"}
                download
                class="rounded-lg border border-purple-600 bg-white px-5 py-3 text-sm font-semibold text-purple-600 transition-colors hover:bg-purple-300"
              >
                Download CV
              </a>
              <a
                href={~p"/"}
                class="rounded-lg border border-purple-100 bg-white px-5 py-3 text-sm font-medium text-slate-700 hover:bg-purple-300"
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

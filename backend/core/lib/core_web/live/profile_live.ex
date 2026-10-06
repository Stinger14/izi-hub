defmodule CoreWeb.ProfileLive do
  use CoreWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket |> assign_new(:current_scope, fn -> nil end) |> assign(show_full_intro: false)}
  end

  def handle_event("toggle_intro", _params, socket) do
    {:noreply, update(socket, :show_full_intro, &(!&1))}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} theme="hub">
      <div class="min-h-screen px-6 py-16">
        <div class="mx-auto flex min-h-[calc(100vh-8rem)] items-center justify-center">
          <div class="hub-glass w-full max-w-3xl rounded-2xl p-8">
            <div class="flex items-center justify-between">
              <p class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--hub-accent-2)]">Profile</p>
              <a
                href={~p"/hub"}
                class="btn btn-secondary btn-sm"
              >
                Back home
              </a>
            </div>

            <div class="mt-6 flex flex-col gap-4 sm:flex-row sm:items-center">
              <div class="relative mx-auto sm:mx-0">
                <div class="h-28 w-28 rounded-full bg-linear-to-br from-[var(--hub-accent-2)] via-[var(--hub-accent)] to-[var(--hub-primary)] p-[3px] shadow-[0_0_32px_-6px_rgba(139,92,246,0.6)]">
                  <img
                    src={~p"/images/pp3.jpeg"}
                    alt="Profile picture of Maxly Garcia"
                    class="h-full w-full rounded-full object-cover ring-4 ring-[color:var(--hub-bg)]"
                  />
                </div>
              </div>
              <div class="text-center sm:text-left">
                <h1 class="font-display text-3xl text-[var(--hub-text)]">Maxly García</h1>
                <p class="mt-1 text-sm text-[var(--hub-muted)]">Software Engineer</p>
              </div>
            </div>

            <div class="mt-4">
              <p class="text-sm text-[var(--hub-muted)]">
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
                class="btn btn-ghost btn-xs mt-2"
              >
                <%= if @show_full_intro, do: "Show less", else: "Read more" %>
              </button>
            </div>

            <div class="mt-6 grid gap-6 md:grid-cols-2">
              <div class="space-y-6">
                <div>
                  <h2 class="text-sm font-semibold text-[var(--hub-text)]">Focus</h2>
                  <p class="mt-2 text-sm text-[var(--hub-muted)]">
                    Backend & distributed systems, LiveView, FastAPI, Docker, Kubernetes and product‑grade integrations.
                  </p>
                </div>
                <div class="border-t border-[color:var(--hub-border)] pt-4">
                  <div
                    id="profile-stack-preview"
                    class="fx-stack-card rounded-xl border border-transparent p-1 transition-colors"
                    phx-hook="StackPreview"
                  >
                    <div class="fx-trigger rounded-xl p-4 text-sm">
                      <div class="flex items-center justify-between gap-3">
                        <h2 class="text-sm font-semibold text-[var(--hub-text)]">Stack</h2>
                      </div>

                      <div class="fx-stack-badge-grid mt-3 grid grid-cols-2 gap-2 md:grid-cols-3">
                        <%= for item <- stack_items() do %>
                          <button
                            type="button"
                            class="fx-stack-badge"
                            data-stack-slug={item.slug}
                            data-stack-title={item.title}
                            data-stack-context={item.context}
                          >
                            <%= item.title %>
                          </button>
                        <% end %>
                      </div>

                      <div class="fx-stack-shared-preview" data-stack-preview>
                        <div class="fx-preview-content">
                          <p
                            data-stack-preview-title
                            class="hidden text-[10px] font-semibold uppercase tracking-[0.14em] text-[var(--hub-accent-2)]"
                          >
                          </p>
                          <p data-stack-preview-context class="mt-2 hidden text-xs text-[var(--hub-muted)]"></p>
                          <p data-stack-preview-hint class="text-xs text-[var(--hub-muted)]">
                          </p>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              <div>
                <div class="fx-item rounded-xl border border-transparent p-1 transition-colors hover:border-[color:var(--hub-border)]">
                  <div class="fx-trigger rounded-xl p-4 text-sm">
                    <h2 class="text-sm font-semibold text-[var(--hub-text)]">Contact</h2>
                    <div class="mt-3 flex flex-col gap-2">
                      <a
                        href="mailto:maxgarcia6@gmail.com"
                        class="fx-contact-link"
                      >
                        Email
                      </a>
                      <a
                        href="https://www.linkedin.com/in/maxly-garcia-bb3110129/"
                        class="fx-contact-link"
                      >
                        LinkedIn
                      </a>
                    </div>
                    <div class="mt-4">
                      <p class="text-xs font-semibold uppercase tracking-wide text-[var(--hub-muted)]">
                        GitHub Accounts
                      </p>
                      <div class="mt-2 flex flex-col gap-2">
                        <a
                          href="https://github.com/Stinger14"
                          class="fx-contact-link"
                        >
                          Stinger14
                        </a>
                        <a
                          href="https://github.com/ghost1ndshell"
                          class="fx-contact-link"
                        >
                          ghost1ndshell
                        </a>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div class="mt-8">
              <div class="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
                <h2 class="text-sm font-semibold text-[var(--hub-text)]">Books</h2>
                <p class="text-xs text-[var(--hub-muted)]">Scroll to explore the full list.</p>
              </div>
              <div id="books-scroll" class="relative mt-3" phx-hook="ScrollHint">
                <div class="flex flex-nowrap gap-2 overflow-x-auto pb-1" data-scroll-container>
                  <span
                    :for={{title, category} <- book_items()}
                    title={category}
                    class={[
                      "inline-flex items-center whitespace-nowrap rounded-full border px-3 py-1 text-xs font-medium",
                      book_chip_class(category)
                    ]}
                  >
                    <%= title %>
                  </span>
                </div>
                <div
                  data-scroll-hint
                  class="pointer-events-none absolute right-2 top-2 rounded-full bg-[color:var(--hub-primary)]/85 px-2 py-1 text-[10px] uppercase tracking-wide text-white opacity-0 transition"
                >
                  Scroll
                </div>
                <div class="pointer-events-none absolute inset-y-0 right-0 w-12 bg-linear-to-l from-[var(--hub-card)] to-transparent">
                </div>
              </div>
              <div class="mt-3 flex flex-wrap items-center gap-3 text-xs text-[var(--hub-muted)]">
                <span :for={category <- book_categories()} class="inline-flex items-center gap-2">
                  <span class={["h-2 w-2 rounded-full", book_dot_class(category)]}></span>
                  <%= category %>
                </span>
              </div>
            </div>

            <div class="mt-8 flex flex-wrap items-center gap-4">
              <a
                href={~p"/cv"}
                target="cv_download_frame"
                class="btn btn-primary btn-glow"
              >
                Download CV
              </a>
            </div>
            <%= if is_nil(@current_scope) do %>
              <p class="mt-2 text-xs text-[var(--hub-muted)]">
                Want updates on new projects and CV revisions?
                <a href={~p"/signup"} class="font-medium text-[var(--hub-secondary)] transition hover:text-[var(--hub-accent-2)]">
                  Sign up
                </a>
              </p>
            <% end %>
            <iframe name="cv_download_frame" class="hidden" aria-hidden="true"></iframe>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # Book categories are a categorical palette (not a status), so they keep
  # distinct hues as dark-theme tints rather than going through tone_class/2.
  @book_categories [
    {"Fundamentals", "border-amber-300/30 bg-amber-300/10 text-amber-200", "bg-amber-300"},
    {"Elixir", "border-violet-300/30 bg-violet-400/15 text-violet-200", "bg-violet-300"},
    {"Python", "border-emerald-300/30 bg-emerald-300/10 text-emerald-200", "bg-emerald-300"},
    {"Database", "border-sky-300/30 bg-sky-300/10 text-sky-200", "bg-sky-300"}
  ]

  defp book_categories, do: Enum.map(@book_categories, &elem(&1, 0))

  defp book_chip_class(category), do: category |> book_category() |> elem(1)

  defp book_dot_class(category), do: category |> book_category() |> elem(2)

  defp book_category(category), do: List.keyfind(@book_categories, category, 0)

  defp book_items do
    [
      {"Smalltalk Best Practice Patterns", "Fundamentals"},
      {"Django for Professionals", "Python"},
      {"Gang of 4", "Fundamentals"},
      {"The Pragmatic Programmer", "Fundamentals"},
      {"Clean Code", "Fundamentals"},
      {"Elixir in Action", "Elixir"},
      {"The Mythical Man-Month", "Fundamentals"},
      {"Programming Phoenix >= 1.4", "Elixir"},
      {"Programming Elixir >= 1.6", "Elixir"},
      {"Programming Ecto", "Database"},
      {"Cracking the Coding Interview", "Fundamentals"}
    ]
  end

  defp stack_items do
    [
      %{
        slug: "elixir",
        title: "Elixir",
        context: "Phoenix + LiveView"
      },
      %{
        slug: "python",
        title: "Python",
        context: "FastAPI, Django, Pandas"
      },
      %{
        slug: "docker",
        title: "Docker",
        context: "Local & production enviroments containers."
      },
      %{
        slug: "k8s",
        title: "Kubernetes",
        context: "Service orchestration"
      },
      %{
        slug: "aws-s3",
        title: "AWS S3",
        context: "Object storage in buckets"
      },
      %{
        slug: "gcp",
        title: "Google Cloud",
        context: "Cloud infrastructure services."
      },
      %{
        slug: "postgres",
        title: "Postgres",
        context: "Primary relational datastore."
      },
      %{
        slug: "redis / ets",
        title: "Redis / Ets",
        context: "Caching, data persistance & pub/sub."
      }
    ]
  end
end

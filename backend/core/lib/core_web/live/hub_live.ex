defmodule CoreWeb.HubLive do
  use CoreWeb, :live_view

  import CoreWeb.HubComponents

  def mount(_params, _session, socket) do
    month = month_start(Date.utc_today())

    {:ok,
     socket
     |> assign_new(:current_scope, fn -> nil end)
     |> assign(
       calendar_month: month,
       calendar_days: calendar_days(month, nil),
       calendar_weekdays: ~w(Sun Mon Tue Wed Thu Fri Sat),
       selected_date: nil,
       stats_variant: "creator",
       translator_open: false,
       translator_text: "",
       translator_direction: "en-es"
     )}
  end

  def handle_event("toggle_translator", _params, socket) do
    {:noreply, update(socket, :translator_open, &(!&1))}
  end

  def handle_event("close_translator", _params, socket) do
    {:noreply, assign(socket, :translator_open, false)}
  end

  def handle_event("translator_input", %{"translator" => params}, socket) do
    text = params |> Map.get("text", "") |> String.slice(0, 5_000)
    direction = normalize_translator_direction(Map.get(params, "direction"))

    {:noreply,
     assign(socket,
       translator_text: text,
       translator_direction: direction
     )}
  end

  def handle_event("toggle_translator_direction", _params, socket) do
    direction = if socket.assigns.translator_direction == "en-es", do: "es-en", else: "en-es"
    {:noreply, assign(socket, :translator_direction, direction)}
  end

  def handle_event("set_stats_variant", %{"variant" => variant}, socket) do
    if variant in stats_variants() do
      {:noreply, assign(socket, :stats_variant, variant)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("prev_calendar_month", _params, socket) do
    month = previous_month(socket.assigns.calendar_month)

    {:noreply,
     assign(socket,
       calendar_month: month,
       calendar_days: calendar_days(month, socket.assigns.selected_date)
     )}
  end

  def handle_event("next_calendar_month", _params, socket) do
    month = next_month(socket.assigns.calendar_month)

    {:noreply,
     assign(socket,
       calendar_month: month,
       calendar_days: calendar_days(month, socket.assigns.selected_date)
     )}
  end

  def handle_event("select_calendar_date", %{"date" => value}, socket) do
    case Date.from_iso8601(value) do
      {:ok, date} ->
        month = month_start(date)

        {:noreply,
         assign(socket,
           selected_date: date,
           calendar_month: month,
           calendar_days: calendar_days(month, date)
         )}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} theme="hub">
      <main class="min-h-screen max-w-none p-0">
        <header class="sticky top-2 z-50 mx-auto max-w-[1440px] px-4 pt-2 sm:px-8">
          <div
            class="relative"
            phx-click-away="close_translator"
            phx-window-keydown="close_translator"
            phx-key="Escape"
          >
            <div class="hub-glass flex items-center gap-2 rounded-2xl border border-[color:var(--hub-border)] bg-[color:var(--hub-card)]/95 p-2 shadow-[0_16px_32px_-20px_var(--hub-shadow)] backdrop-blur">
              <a
                href={~p"/welcome"}
                class="font-display hidden shrink-0 px-2 text-base text-[var(--hub-secondary)] sm:block"
              >
                Workspace
              </a>
              <nav
                aria-label="Command center"
                class="flex min-w-0 flex-1 items-center gap-1.5 overflow-x-auto rounded-xl bg-[var(--hub-bg)]/60 p-1"
              >
                <a href="#tasks" class={command_chip_class(false)}>
                  <.icon name="hero-check" class="h-4 w-4 text-[var(--hub-secondary)]" />Tasks
                </a>
                <button
                  type="button"
                  phx-click="toggle_translator"
                  aria-expanded={to_string(@translator_open)}
                  aria-controls="translator-popover"
                  class={command_chip_class(@translator_open)}
                >
                  <.icon name="hero-arrow-path" class="h-4 w-4 text-[var(--hub-secondary)]" />Translate
                </button>
                <button
                  type="button"
                  disabled
                  title="Music connection coming soon"
                  class={command_chip_class(:disabled)}
                >
                  <.icon name="hero-musical-note" class="h-4 w-4" />Music
                </button>
                <button
                  type="button"
                  disabled
                  title="Gmail connection coming soon"
                  class={command_chip_class(:disabled)}
                >
                  <.icon name="hero-envelope" class="h-4 w-4" />Gmail
                </button>
              </nav>
              <details class="relative shrink-0">
                <summary class="inline-flex h-9 cursor-pointer list-none items-center gap-1.5 rounded-lg border border-[color:var(--hub-border)] bg-[var(--hub-card)] px-3 text-xs font-semibold text-[var(--hub-text)] transition hover:border-[color:var(--hub-accent)] focus:outline-none focus:ring-2 focus:ring-[color:var(--hub-accent)]/40">
                  <.icon name="hero-ellipsis-horizontal" class="h-4 w-4 text-[var(--hub-secondary)]" />Pages
                </summary>
                <div class="hub-glass absolute right-0 top-full z-[60] mt-2 grid w-52 gap-1 rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-card)] p-2 shadow-[0_24px_40px_-20px_var(--hub-shadow)]">
                  <a
                    :for={{label, path, auth?} <- page_links()}
                    :if={!auth? or @current_scope}
                    href={path}
                    class="rounded-lg px-3 py-2 text-sm font-medium text-[var(--hub-text)] transition hover:bg-[var(--hub-surface)] hover:text-[var(--hub-primary)]"
                  >
                    <%= label %>
                  </a>
                </div>
              </details>
              <a
                :if={is_nil(@current_scope)}
                href={~p"/login"}
                class="btn btn-primary btn-xs shrink-0"
              >
                Sign in
              </a>
            </div>
            <section
              :if={@translator_open}
              id="translator-popover"
              role="dialog"
              aria-label="Translator"
              class="hub-glass mt-2 w-full rounded-2xl border border-[color:var(--hub-border)] bg-[var(--hub-card)] p-3 shadow-[0_16px_32px_-20px_var(--hub-shadow)] sm:p-4"
            >
              <form
                id="translator-form"
                phx-change="translator_input"
                class="grid grid-cols-1 items-center gap-2 sm:grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)]"
              >
                <label for="translator-text" class="sr-only">
                  Text in <%= translator_source_language(@translator_direction) %>
                </label>
                <input type="hidden" name="translator[direction]" value={@translator_direction} />
                <textarea
                  id="translator-text"
                  name="translator[text]"
                  rows="1"
                  maxlength="5000"
                  autofocus
                  phx-debounce="500"
                  phx-hook="AutoGrow"
                  placeholder={translator_source_language(@translator_direction)}
                  aria-label={translator_source_language(@translator_direction)}
                  class={translator_field_class()}
                ><%= @translator_text %></textarea>
                <button
                  type="button"
                  phx-click="toggle_translator_direction"
                  aria-label="Swap English and Spanish"
                  title="Swap languages"
                  class="mx-auto inline-flex h-9 w-9 items-center justify-center rounded-full border border-[color:var(--hub-border)] bg-[var(--hub-surface)] text-[var(--hub-secondary)] transition hover:border-[color:var(--hub-accent)] focus:outline-none focus:ring-2 focus:ring-[color:var(--hub-accent)]/40"
                >
                  <.icon name="hero-arrow-path" class="h-4 w-4" />
                </button>
                <label for="translator-result" class="sr-only">
                  Translation in <%= translator_target_language(@translator_direction) %>
                </label>
                <textarea
                  id="translator-result"
                  readonly
                  rows="1"
                  phx-hook="AutoGrow"
                  placeholder={translator_target_language(@translator_direction)}
                  aria-label={translator_target_language(@translator_direction)}
                  class={translator_field_class()}
                ></textarea>
              </form>
            </section>
          </div>
        </header>

        <div class="mx-auto max-w-[1440px] space-y-5 px-4 py-6 sm:px-8 sm:py-8">
          <div class="flex flex-wrap items-end justify-between gap-3 px-1">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--hub-accent-2)]">
                Your workspace
              </p>
              <h1 class="font-display mt-1 text-4xl text-[var(--hub-text)] sm:text-5xl">Dashboard</h1>
            </div>
            <p class="text-sm text-[var(--hub-muted)]">
              <%= Calendar.strftime(Date.utc_today(), "%A, %B %-d") %>
            </p>
          </div>

          <div class="grid gap-5 lg:grid-cols-2">
            <.finance_card current_scope={@current_scope} />
            <.role_stats_card variant={@stats_variant} current_scope={@current_scope} />
          </div>

          <div class="grid gap-5 lg:grid-cols-[minmax(0,1fr)_320px]">
            <.tasks_panel />
            <aside class="grid content-start gap-5" aria-label="Sidebar">
              <.calendar_card
                month={@calendar_month}
                days={@calendar_days}
                weekdays={@calendar_weekdays}
                selected_date={@selected_date}
              />
              <.music_card />
              <.library_shortcuts current_scope={@current_scope} />
              <.gmail_preview />
            </aside>
          </div>
        </div>
      </main>
    </Layouts.app>
    """
  end

  defp calendar_days(calendar_month, selected_date) do
    first_day = month_start(calendar_month)
    last_day = Date.add(first_day, Date.days_in_month(first_day) - 1)
    grid_start = Date.add(first_day, -rem(Date.day_of_week(first_day), 7))
    grid_end = Date.add(last_day, 6 - rem(Date.day_of_week(last_day), 7))
    day_count = Date.diff(grid_end, grid_start) + 1

    Enum.map(0..(day_count - 1), fn offset ->
      date = Date.add(grid_start, offset)

      %{
        date: date,
        in_month?: date.month == calendar_month.month and date.year == calendar_month.year,
        selected?: match?(%Date{}, selected_date) and Date.compare(date, selected_date) == :eq,
        label: Integer.to_string(date.day)
      }
    end)
  end

  defp month_start(%Date{} = date), do: %{date | day: 1}

  defp previous_month(%Date{} = month) do
    month |> Date.add(-1) |> month_start()
  end

  defp next_month(%Date{} = month) do
    month |> Date.add(Date.days_in_month(month)) |> month_start()
  end

  defp normalize_translator_direction("es-en"), do: "es-en"
  defp normalize_translator_direction(_direction), do: "en-es"

  defp translator_source_language("en-es"), do: "English"
  defp translator_source_language("es-en"), do: "Spanish"

  defp translator_target_language("en-es"), do: "Spanish"
  defp translator_target_language("es-en"), do: "English"

  defp page_links do
    [
      {"Dashboard", ~p"/hub", false},
      {"Finance", ~p"/finance", true},
      {"Books & notebooks", ~p"/notebooks", true},
      {"Resources", ~p"/resources", false},
      {"Live Apps", ~p"/liveapps", false},
      {"Contributions", ~p"/contributions", true},
      {"Profile", ~p"/profile", false},
      {"Welcome", ~p"/welcome", false}
    ]
  end

  defp command_chip_class(:disabled) do
    "inline-flex h-8 shrink-0 cursor-not-allowed items-center gap-1.5 rounded-lg border border-transparent px-2.5 text-xs font-medium text-[var(--hub-muted)] opacity-70"
  end

  defp command_chip_class(true) do
    "inline-flex h-8 shrink-0 items-center gap-1.5 rounded-lg border border-[color:var(--hub-accent)] bg-[color:var(--hub-accent)]/15 px-2.5 text-xs font-semibold text-[var(--hub-primary)] transition"
  end

  defp command_chip_class(false) do
    "inline-flex h-8 shrink-0 items-center gap-1.5 rounded-lg border border-[color:var(--hub-border)] bg-[var(--hub-card)] px-2.5 text-xs font-semibold text-[var(--hub-text)] transition hover:border-[color:var(--hub-accent)]"
  end

  defp translator_field_class do
    "min-h-10 max-h-40 w-full resize-none overflow-y-auto rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-3 py-2.5 text-sm text-[var(--hub-text)] outline-none transition placeholder:text-[var(--hub-muted)] focus:border-[color:var(--hub-accent)] focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
  end
end

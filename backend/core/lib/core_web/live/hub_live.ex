defmodule CoreWeb.HubLive do
  use CoreWeb, :live_view

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
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <main class="min-h-screen bg-purple-50 text-slate-900">
        <header class="sticky top-2 z-50 mx-auto max-w-[1680px] px-5 sm:px-8">
          <div class="relative" phx-click-away="close_translator" phx-window-keydown="close_translator" phx-key="Escape">
          <div class="flex items-center gap-2 rounded-2xl border border-purple-100 bg-white/95 p-2 shadow-md shadow-purple-900/5 backdrop-blur">
            <a href={~p"/welcome"} class="shrink-0 px-2 font-display text-xs font-semibold uppercase tracking-[0.12em] text-slate-600">Workspace</a>
            <nav aria-label="Command center" class="flex min-w-0 flex-1 items-center gap-1.5 overflow-x-auto rounded-xl bg-purple-50/70 p-1">
              <a href="#tasks" class="inline-flex h-8 shrink-0 items-center gap-1.5 rounded-lg border border-purple-100 bg-white px-2.5 text-xs font-semibold text-slate-700 transition hover:border-purple-200 hover:bg-purple-50"><.icon name="hero-check" class="h-4 w-4 text-purple-600" />Tasks</a>
              <button type="button" phx-click="toggle_translator" aria-expanded={@translator_open} aria-controls="translator-popover" class={translator_button_class(@translator_open)}><.icon name="hero-arrow-path" class="h-4 w-4 text-purple-600" />Translate</button>
              <button type="button" disabled title="Music connection coming soon" class="inline-flex h-8 shrink-0 items-center gap-1.5 rounded-lg border border-slate-100 bg-slate-50 px-2.5 text-xs font-medium text-slate-500"><span class="inline-flex h-4 w-4 items-center justify-center rounded bg-white text-sm text-slate-500" aria-hidden="true">♫</span>Music</button>
              <button type="button" disabled title="Gmail connection coming soon" class="inline-flex h-8 shrink-0 items-center gap-1.5 rounded-lg border border-slate-100 bg-slate-50 px-2.5 text-xs font-medium text-slate-500"><span class="inline-flex h-4 w-4 items-center justify-center rounded bg-white text-[10px] font-bold text-slate-500" aria-hidden="true">M</span>Gmail</button>
            </nav>
            <details class="relative shrink-0">
              <summary class="inline-flex h-9 cursor-pointer list-none items-center gap-1.5 rounded-lg border border-purple-100 bg-white px-3 text-xs font-semibold text-slate-700 transition hover:border-purple-200 hover:bg-purple-50 focus:outline-none focus:ring-2 focus:ring-purple-200">
                <.icon name="hero-ellipsis-horizontal" class="h-4 w-4 text-purple-600" />Pages
              </summary>
              <div class="absolute right-0 top-full z-[60] mt-2 grid w-52 gap-1 rounded-xl border border-purple-100 bg-white p-2 shadow-xl shadow-purple-900/10">
                <a href={~p"/hub"} class="rounded-lg px-3 py-2 text-sm font-medium text-slate-700 hover:bg-purple-50 hover:text-purple-700">Dashboard</a>
                <a :if={@current_scope} href={~p"/finance"} class="rounded-lg px-3 py-2 text-sm font-medium text-slate-700 hover:bg-purple-50 hover:text-purple-700">Finance</a>
                <a :if={@current_scope} href={~p"/notebooks"} class="rounded-lg px-3 py-2 text-sm font-medium text-slate-700 hover:bg-purple-50 hover:text-purple-700">Books &amp; notebooks</a>
                <a href={~p"/resources"} class="rounded-lg px-3 py-2 text-sm font-medium text-slate-700 hover:bg-purple-50 hover:text-purple-700">Resources</a>
                <a href={~p"/liveapps"} class="rounded-lg px-3 py-2 text-sm font-medium text-slate-700 hover:bg-purple-50 hover:text-purple-700">Live Apps</a>
                <a :if={@current_scope} href={~p"/contributions"} class="rounded-lg px-3 py-2 text-sm font-medium text-slate-700 hover:bg-purple-50 hover:text-purple-700">Contributions</a>
                <a href={~p"/profile"} class="rounded-lg px-3 py-2 text-sm font-medium text-slate-700 hover:bg-purple-50 hover:text-purple-700">Profile</a>
                <a href={~p"/welcome"} class="rounded-lg px-3 py-2 text-sm font-medium text-slate-700 hover:bg-purple-50 hover:text-purple-700">Welcome</a>
              </div>
            </details>
            <div class="shrink-0">
              <%= if is_nil(@current_scope) do %>
                <a href={~p"/login"} class="btn btn-primary btn-xs">Sign in</a>
              <% else %>
                <a href={~p"/profile"} class="inline-flex h-8 items-center rounded-lg px-3 text-xs font-semibold text-purple-600 transition hover:bg-purple-50">Profile</a>
              <% end %>
            </div>
          </div>
          <section :if={@translator_open} id="translator-popover" role="dialog" aria-label="Translator" class="mt-2 w-full rounded-2xl border border-purple-100 bg-white p-3 shadow-md shadow-purple-900/5 sm:p-4">
            <form id="translator-form" phx-change="translator_input" class="grid grid-cols-1 items-center gap-2 sm:grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)]">
              <label for="translator-text" class="sr-only">Text in {translator_source_language(@translator_direction)}</label>
              <input type="hidden" name="translator[direction]" value={@translator_direction} />
              <textarea id="translator-text" name="translator[text]" rows="1" maxlength="5000" autofocus phx-debounce="500" phx-hook="AutoGrow" placeholder={translator_source_language(@translator_direction)} aria-label={translator_source_language(@translator_direction)} class="min-h-10 max-h-40 w-full resize-none overflow-y-auto rounded-xl border border-purple-100 bg-purple-50/40 px-3 py-2.5 text-sm text-slate-800 outline-none transition placeholder:text-slate-400 focus:border-purple-300 focus:bg-white focus:ring-2 focus:ring-purple-100"><%= @translator_text %></textarea>
              <button type="button" phx-click="toggle_translator_direction" aria-label="Swap English and Spanish" title="Swap languages" class="mx-auto inline-flex h-9 w-9 items-center justify-center rounded-full border border-purple-100 bg-white text-purple-700 transition hover:border-purple-300 hover:bg-purple-50 focus:outline-none focus:ring-2 focus:ring-purple-200"><.icon name="hero-arrow-path" class="h-4 w-4" /></button>
              <label for="translator-result" class="sr-only">Translation in {translator_target_language(@translator_direction)}</label>
              <textarea id="translator-result" readonly rows="1" phx-hook="AutoGrow" placeholder={translator_target_language(@translator_direction)} aria-label={translator_target_language(@translator_direction)} class="min-h-10 max-h-40 w-full resize-none overflow-y-auto rounded-xl border border-purple-100 bg-white px-3 py-2.5 text-sm text-slate-800 outline-none placeholder:text-slate-400"></textarea>
            </form>
          </section>
          </div>
        </header>

        <div class="mx-auto max-w-[1680px] px-5 py-6 sm:px-8 sm:py-8">
          <div class="space-y-5">
            <section class="rounded-3xl border border-purple-100 bg-white/95 p-6 shadow-lg shadow-purple-900/5 sm:p-8 lg:p-10">
                <div class="mb-7 flex flex-wrap items-center justify-between gap-3 sm:mb-8">
                  <div><p class="text-xs font-semibold uppercase tracking-[0.14em] text-purple-600">Your workspace</p><h1 class="mt-1 font-display text-3xl font-semibold tracking-tight text-slate-900 sm:text-4xl">Dashboard</h1></div>
                  <a href={~p"/welcome"} class="text-sm font-medium text-purple-600 hover:text-purple-700">Welcome <.icon name="hero-arrow-right" class="ml-1 inline h-4 w-4" /></a>
                </div>
                <div class="grid gap-5 lg:grid-cols-2 lg:gap-6">
                  <article class="rounded-2xl border border-purple-100 bg-white p-5 shadow-sm shadow-purple-900/5 sm:p-6">
                    <div><p class="text-xs font-semibold uppercase tracking-wide text-purple-600">Finance</p><h2 class="mt-1 text-lg font-semibold text-slate-900">Your money, at a glance</h2></div>
                    <div class="mt-5 grid grid-cols-2 gap-3"><div class="min-w-0 rounded-xl border border-purple-100/70 bg-purple-50/60 p-3 sm:p-4"><p class="text-xs text-slate-500">Balances</p><p class="mt-2 text-sm font-semibold leading-snug text-slate-800">Connect account</p></div><div class="min-w-0 rounded-xl border border-purple-100/70 bg-purple-50/60 p-3 sm:p-4"><p class="text-xs text-slate-500">Monthly spending</p><p class="mt-2 text-sm font-semibold leading-snug text-slate-800">No data yet</p></div></div>
                    <a href={if @current_scope, do: ~p"/finance", else: ~p"/login"} class="mt-5 inline-flex items-center gap-1 rounded-lg px-2 py-1.5 text-sm font-semibold text-purple-700 transition hover:bg-purple-50">Open Finance <.icon name="hero-arrow-right" class="h-4 w-4" /></a>
                  </article>
                  <article class="rounded-2xl border border-purple-100 bg-purple-50/70 p-5 shadow-sm shadow-purple-900/5 sm:p-6">
                    <div class="flex items-start justify-between gap-3"><div><p class="text-xs font-semibold uppercase tracking-wide text-purple-600">Social &amp; creator stats</p><h2 class="mt-1 text-lg font-semibold text-slate-900">Your reach and activity</h2></div><a :if={@current_scope} href={~p"/contributions"} class="shrink-0 rounded-lg px-2 py-1 text-xs font-semibold text-purple-700 transition hover:bg-white/70">GitHub details</a></div>
                    <div class="mt-5 grid grid-cols-2 gap-3"><div class="min-w-0 rounded-xl border border-purple-100/70 bg-white p-3 sm:p-4"><p class="text-xs text-slate-500">Creator</p><p class="mt-2 text-sm font-semibold leading-snug text-slate-800">Connect account</p><p class="mt-1 text-xs leading-snug text-slate-500">Followers, views, engagement</p></div><div class="min-w-0 rounded-xl border border-purple-100/70 bg-white p-3 sm:p-4"><p class="text-xs text-slate-500">Developer</p><p class="mt-2 text-sm font-semibold leading-snug text-slate-800">GitHub activity</p><p class="mt-1 text-xs leading-snug text-slate-500">Connect to see your stats</p></div></div>
                  </article>
                </div>
            </section>

            <div class="grid items-start gap-5 lg:grid-cols-[minmax(0,1fr)_280px]">
              <section id="tasks" class="rounded-2xl border border-purple-100 bg-white/90 p-5 shadow-sm sm:p-6">
                <div class="flex flex-wrap items-center justify-between gap-3">
                  <div><p class="text-xs font-semibold uppercase tracking-[0.14em] text-purple-600">Focus</p><h2 class="mt-1 text-xl font-semibold text-slate-900">Tasks</h2></div>
                </div>
                <div class="mt-4 flex items-center gap-3 rounded-xl border border-purple-100 bg-purple-50/45 px-4 py-4">
                  <span class="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-white text-purple-600"><.icon name="hero-check" class="h-4 w-4" /></span>
                  <div><p class="text-sm font-semibold text-slate-800">No tasks yet</p><p class="mt-0.5 text-xs text-slate-500">Your tasks will appear here.</p></div>
                </div>
              </section>
              <aside class="lg:pt-1">
              <section class="rounded-2xl border border-purple-100 bg-white p-3 shadow-sm">
                <div class="flex items-center justify-between gap-2"><div><p class="text-[10px] font-semibold uppercase tracking-[0.14em] text-purple-600">Calendar</p><h2 class="text-sm font-semibold text-slate-900"><%= calendar_month_label(@calendar_month) %></h2></div><div class="flex gap-1"><button type="button" phx-click="prev_calendar_month" aria-label="Previous month" class="grid h-8 w-8 place-items-center rounded-lg text-purple-700 transition hover:bg-purple-50"><.icon name="hero-arrow-left" class="h-3.5 w-3.5" /></button><button type="button" phx-click="next_calendar_month" aria-label="Next month" class="grid h-8 w-8 place-items-center rounded-lg text-purple-700 transition hover:bg-purple-50"><.icon name="hero-arrow-right" class="h-3.5 w-3.5" /></button></div></div>
                <div class="mt-2 grid grid-cols-7 text-center text-[10px] font-semibold uppercase tracking-wide text-slate-500"><span :for={weekday <- @calendar_weekdays}><%= weekday %></span></div>
                <div class="mt-1 grid grid-cols-7 gap-y-0"><button :for={day <- @calendar_days} type="button" phx-click="select_calendar_date" phx-value-date={Date.to_iso8601(day.date)} aria-pressed={day.selected?} class={calendar_day_class(day)}><%= day.label %></button></div>
                <p class="mt-2 border-t border-purple-100 pt-2 text-[10px] text-slate-500"><%= if @selected_date, do: Calendar.strftime(@selected_date, "%a, %b %-d"), else: "Select a date" %></p>
              </section>
              </aside>
            </div>
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

  defp calendar_month_label(%Date{} = date), do: Calendar.strftime(date, "%B %Y")

  defp normalize_translator_direction("es-en"), do: "es-en"
  defp normalize_translator_direction(_direction), do: "en-es"

  defp translator_source_language("en-es"), do: "English"
  defp translator_source_language("es-en"), do: "Spanish"

  defp translator_target_language("en-es"), do: "Spanish"
  defp translator_target_language("es-en"), do: "English"

  defp translator_button_class(true) do
    "inline-flex h-8 shrink-0 items-center gap-1.5 rounded-lg border border-purple-300 bg-purple-100 px-2.5 text-xs font-semibold text-purple-800 transition"
  end

  defp translator_button_class(false) do
    "inline-flex h-8 shrink-0 items-center gap-1.5 rounded-lg border border-purple-100 bg-white px-2.5 text-xs font-semibold text-slate-700 transition hover:border-purple-200 hover:bg-purple-50"
  end

  defp calendar_day_class(day) do
    base =
      "grid h-8 w-full place-items-center rounded-lg text-xs leading-none transition-colors"

    cond do
      day.selected? ->
        base <> " bg-purple-600 font-semibold text-white shadow-sm shadow-purple-900/15"

      day.in_month? ->
        base <> " text-slate-700 hover:bg-purple-50"

      true ->
        base <> " text-slate-300 hover:bg-purple-50/70"
    end
  end
end

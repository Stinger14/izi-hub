defmodule CoreWeb.HubLive do
  use CoreWeb, :live_view

  import CoreWeb.HubComponents

  alias Core.{Accounts, Finance, GitHub, Office}
  alias CoreWeb.{FinanceComponents, LiveReload}
  alias Phoenix.LiveView.AsyncResult

  def mount(_params, _session, socket) do
    month = month_start(Date.utc_today())

    # The hub is sign-in only (the router's :authenticated live_session).
    user = current_user(socket)

    if connected?(socket) do
      Office.subscribe(user)
      Finance.subscribe(user)
    end

    {:ok,
     socket
     |> assign(
       calendar_month: month,
       calendar_days: [],
       calendar_weekdays: ~w(Sun Mon Tue Wed Thu Fri Sat),
       selected_date: nil,
       stats_variant: "developer",
       translator_open: false,
       translator_text: "",
       translator_direction: "en-es"
     )
     |> assign(
       task_form: task_form(%{}),
       editing_hub_task_id: nil,
       hub_task_form: nil,
       confirming_hub_task_delete_id: nil
     )
     |> assign_office()
     |> assign_finance_card("personal")
     |> assign(github_editing: false, github_form: github_form(%{}))
     |> assign_developer()}
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

  def handle_event("set_finance_scope", %{"scope" => scope}, socket)
      when scope in ["personal", "household"] do
    {:noreply, assign_finance_card(socket, scope)}
  end

  def handle_event("set_finance_scope", _params, socket), do: {:noreply, socket}

  def handle_event("edit_github", _params, socket) do
    login = current_user(socket).github_username

    {:noreply,
     assign(socket, github_editing: true, github_form: github_form(%{"github_username" => login}))}
  end

  def handle_event("cancel_github", _params, socket) do
    {:noreply, assign(socket, github_editing: false, github_form: github_form(%{}))}
  end

  def handle_event("save_github", %{"github" => params}, socket) do
    case Accounts.update_github_username(current_user(socket), params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:current_scope, %{socket.assigns.current_scope | user: user})
         |> assign(github_editing: false, github_form: github_form(%{}))
         |> assign_developer()}

      {:error, changeset} ->
        {:noreply,
         assign(socket, github_editing: true, github_form: to_form(changeset, as: :github))}
    end
  end

  def handle_event("quick_add_task", %{"task" => %{"title" => title}}, socket) do
    user = current_user(socket)

    with title when title != "" <- String.trim(title) do
      date = socket.assigns.selected_date || Date.utc_today()

      case Office.create_work_item(user, Office.default_project_for_user(user), %{
             "title" => title,
             "scheduled_for" => Date.to_iso8601(date)
           }) do
        {:ok, _task} ->
          {:noreply, socket |> assign(task_form: task_form(%{})) |> assign_office()}

        {:error, changeset} ->
          {:noreply, assign(socket, task_form: to_form(changeset, as: :task))}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  # Quick edits from the hub: title and scheduled day. Everything else is
  # edited in IziOffice.
  def handle_event("edit_hub_task", %{"id" => id}, socket) do
    user = current_user(socket)

    with %{} = task <- Office.get_user_work_item(user, id) do
      form =
        to_form(
          %{
            "title" => task.title,
            "scheduled_for" => task.scheduled_for && Date.to_iso8601(task.scheduled_for)
          },
          as: :hub_task
        )

      {:noreply,
       assign(socket,
         editing_hub_task_id: id,
         hub_task_form: form,
         confirming_hub_task_delete_id: nil
       )}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("cancel_hub_task_edit", _params, socket),
    do: {:noreply, assign(socket, editing_hub_task_id: nil, hub_task_form: nil)}

  def handle_event("save_hub_task", %{"hub_task" => params}, socket) do
    user = current_user(socket)

    with %{} = task <- Office.get_user_work_item(user, socket.assigns.editing_hub_task_id),
         {:ok, _task} <-
           Office.update_work_item(task, Map.take(params, ["title", "scheduled_for"])) do
      {:noreply,
       socket
       |> assign(editing_hub_task_id: nil, hub_task_form: nil)
       |> assign_office()}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, hub_task_form: to_form(changeset, as: :hub_task))}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("request_hub_task_delete", %{"id" => id}, socket),
    do: {:noreply, assign(socket, confirming_hub_task_delete_id: id, editing_hub_task_id: nil)}

  def handle_event("cancel_hub_task_delete", _params, socket),
    do: {:noreply, assign(socket, confirming_hub_task_delete_id: nil)}

  def handle_event("delete_hub_task", %{"id" => id}, socket) do
    user = current_user(socket)

    with %{} = task <- Office.get_user_work_item(user, id) do
      Office.delete_work_item(user, task)
    end

    {:noreply, socket |> assign(confirming_hub_task_delete_id: nil) |> assign_office()}
  end

  def handle_event("advance_task", %{"id" => id}, socket) do
    user = current_user(socket)

    with %{} = task <- Office.get_user_work_item(user, id),
         next when is_binary(next) <- Office.next_status(task.status) do
      Office.transition_work_item(task, next, user)
    end

    {:noreply, assign_office(socket)}
  end

  def handle_event("prev_calendar_month", _params, socket) do
    month = previous_month(socket.assigns.calendar_month)

    {:noreply,
     assign(socket,
       calendar_month: month
     )
     |> assign_office()}
  end

  def handle_event("next_calendar_month", _params, socket) do
    month = next_month(socket.assigns.calendar_month)

    {:noreply,
     assign(socket,
       calendar_month: month
     )
     |> assign_office()}
  end

  def handle_event("select_calendar_date", %{"date" => value}, socket) do
    case Date.from_iso8601(value) do
      {:ok, date} ->
        month = month_start(date)

        {:noreply,
         socket
         |> assign(selected_date: date, calendar_month: month)
         |> assign_office()}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  # Office broadcasts {:office_changed, user_id} after every write (here, in
  # IziOffice, or in another tab); reload the tasks panel and calendar.
  def handle_info({:office_changed, _user_id}, socket) do
    LiveReload.drain(:office_changed)
    {:noreply, assign_office(socket)}
  end

  # Finance writes (here, in Finance, from email ingestion, or by another
  # household member) refresh the Finance card in the scope it's showing.
  def handle_info({:finance_changed, _owner}, socket) do
    LiveReload.drain(:finance_changed)
    {:noreply, assign_finance_card(socket, socket.assigns.finance_scope)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} workspace={:hub}>
      <:workspace_tools>
        <a href="#tasks" aria-label="Tasks" title="Tasks" class={Layouts.workspace_chip_class(false)}>
          <.icon name="hero-check" class="h-4 w-4 text-[var(--hub-secondary)]" />
          <span class="hidden sm:inline">Tasks</span>
        </a>
        <%!-- While open, a click anywhere outside the popover closes it
             (phx-click-away), so the chip only opens it. --%>
        <button
          type="button"
          phx-click={unless @translator_open, do: "toggle_translator"}
          aria-expanded={to_string(@translator_open)}
          aria-controls="translator-popover"
          aria-label="Translate"
          title="Translate"
          class={Layouts.workspace_chip_class(@translator_open)}
        >
          <.icon name="hero-arrow-path" class="h-4 w-4 text-[var(--hub-secondary)]" />
          <span class="hidden sm:inline">Translate</span>
        </button>
        <button
          type="button"
          disabled
          title="Music connection coming soon"
          aria-label="Music"
          class={Layouts.workspace_chip_class(:disabled)}
        >
          <.icon name="hero-musical-note" class="h-4 w-4" />
          <span class="hidden sm:inline">Music</span>
        </button>
        <button
          type="button"
          disabled
          title="Gmail connection coming soon"
          aria-label="Gmail"
          class={Layouts.workspace_chip_class(:disabled)}
        >
          <.icon name="hero-envelope" class="h-4 w-4" />
          <span class="hidden sm:inline">Gmail</span>
        </button>
      </:workspace_tools>
      <:workspace_panel>
        <section
          :if={@translator_open}
          id="translator-popover"
          phx-click-away="close_translator"
          phx-window-keydown="close_translator"
          phx-key="Escape"
          role="dialog"
          aria-label="Translator"
          class="hub-glass mt-2 w-full rounded-2xl p-3 shadow-[0_16px_32px_-20px_var(--hub-shadow)] sm:p-4"
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
      </:workspace_panel>
      <main class="min-h-screen max-w-none p-0">
        <div class="mx-auto max-w-[1440px] space-y-5 px-4 py-6 sm:px-8 sm:py-8">
          <div class="flex flex-wrap items-end justify-between gap-3 px-1">
            <h1 class="font-display text-4xl text-[var(--hub-text)] sm:text-5xl">Dashboard</h1>
            <p class="text-sm text-[var(--hub-muted)]">
              <%= Calendar.strftime(Date.utc_today(), "%A, %B %-d") %>
            </p>
          </div>

          <div class="grid gap-5 lg:grid-cols-2">
            <.finance_card
              finance={@finance}
              scope={@finance_scope}
              household={@finance_household}
              invitation_count={@finance_invitations}
            />
            <.role_stats_card
              variant={@stats_variant}
              developer={@developer}
              github_form={@github_form}
              github_editing={@github_editing}
            />
          </div>

          <div class="grid gap-5 lg:grid-cols-[minmax(0,1fr)_320px]">
            <.tasks_panel
              focus={@focus}
              form={@task_form}
              selected_date={@selected_date}
              editing_task_id={@editing_hub_task_id}
              edit_form={@hub_task_form}
              confirming_delete_id={@confirming_hub_task_delete_id}
            />
            <aside class="grid content-start gap-5" aria-label="Sidebar">
              <.calendar_card
                month={@calendar_month}
                days={@calendar_days}
                weekdays={@calendar_weekdays}
                selected_date={@selected_date}
                agenda={@agenda}
              />
              <.music_card />
              <.library_shortcuts />
              <.gmail_preview />
            </aside>
          </div>
        </div>
      </main>
    </Layouts.app>
    """
  end

  defp current_user(socket), do: socket.assigns.current_scope.user

  defp github_form(params), do: to_form(params, as: :github)

  # Developer card data loads async so a slow GitHub call never blocks the hub.
  defp assign_developer(socket) do
    case current_user(socket) do
      %{github_username: login} when is_binary(login) ->
        assign_async(socket, :developer, fn ->
          {:ok, %{developer: {login, GitHub.developer_stats(login)}}}
        end)

      %{} ->
        assign(socket, :developer, AsyncResult.ok(:not_linked))
    end
  end

  # Finance card: reuses Core.Finance so the hub shows the same numbers as the
  # Finance dashboard. Household scope is offered only to household members.
  defp assign_finance_card(socket, scope) do
    user = current_user(socket)
    household = user |> Accounts.list_households_for_user() |> List.first()
    scope = if scope == "household" and household, do: "household", else: "personal"
    owner = if scope == "household", do: household, else: user

    assign(socket,
      finance: finance_snapshot(user, owner, Date.utc_today()),
      finance_scope: scope,
      finance_household: household,
      finance_invitations: length(Accounts.list_pending_invitations_for_user(user))
    )
  end

  defp finance_snapshot(user, owner, today) do
    with {:ok, accounts} <- Finance.list_accounts(user, owner),
         {:ok, budgets} <- Finance.list_budgets(user, owner) do
      month =
        Finance.get_currency_summary(
          owner,
          Date.beginning_of_month(today),
          Date.end_of_month(today),
          exclude_debt_payment_expenses: true
        )

      statuses = Enum.map(budgets, &Finance.check_budget_status/1)

      %{
        accounts_count: length(accounts),
        balance: FinanceComponents.currency_totals(accounts, & &1.current_balance, & &1.currency),
        month_spent: month.expenses,
        month_income: month.income,
        budget_remaining:
          FinanceComponents.currency_totals(statuses, & &1.remaining, & &1.budget.currency),
        budget_remaining_pct:
          case statuses do
            [] ->
              nil

            _ ->
              statuses
              |> Enum.map(& &1.percentage)
              |> Enum.sum()
              |> Kernel./(length(statuses))
              |> FinanceComponents.budget_remaining_pct()
          end
      }
    else
      _ -> nil
    end
  end

  defp task_form(params), do: to_form(params, as: :task)

  # Tasks panel + calendar data from Core.Office (all active projects).
  defp assign_office(socket) do
    user = current_user(socket)
    month = socket.assigns.calendar_month
    selected = socket.assigns.selected_date
    last_day = Date.add(month, Date.days_in_month(month) - 1)
    grid_first = Date.add(month, -rem(Date.day_of_week(month), 7))
    grid_last = Date.add(last_day, 6 - rem(Date.day_of_week(last_day), 7))
    counts = Office.calendar_counts_for_user(user, grid_first, grid_last)

    assign(socket,
      focus: Office.focus_tasks(user, Date.utc_today()),
      agenda: selected && Office.agenda_for_day(user, selected),
      calendar_days: calendar_days(month, selected, counts)
    )
  end

  defp calendar_days(calendar_month, selected_date, counts) do
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
        total_count: counts |> Map.get(date, %{}) |> Map.get(:total_count, 0),
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

  defp translator_field_class do
    "min-h-10 max-h-40 w-full resize-none overflow-y-auto rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-3 py-2.5 text-sm text-[var(--hub-text)] outline-none transition placeholder:text-[var(--hub-muted)] focus:border-[color:var(--hub-accent)] focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
  end
end

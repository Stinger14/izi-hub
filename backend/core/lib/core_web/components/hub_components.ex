defmodule CoreWeb.HubComponents do
  @moduledoc """
  Dashboard widgets for `CoreWeb.HubLive`. Every widget is presentation-only
  and renders an empty state until its feature is wired up. Colors resolve
  through the `--hub-*` tokens scoped to `.hub-shell` (see `app.css`); the
  Finance card reuses `FinanceComponents.fin_card/1` and `tone_class/2`,
  which `.hub-shell` maps onto the hub palette.
  """
  use CoreWeb, :html

  import CoreWeb.FinanceComponents, only: [fin_card: 1, tone_class: 2, money_totals: 1]

  @stats_variants ~w(creator developer)

  def stats_variants, do: @stats_variants

  @doc "Base hub surface: walnut card, hairline border, soft shadow."
  attr :id, :string, default: nil
  attr :kicker, :string, required: true
  attr :title, :string, required: true
  attr :icon, :string, default: nil
  attr :class, :any, default: nil
  slot :actions
  slot :inner_block, required: true

  def hub_card(assigns) do
    ~H"""
    <section
      id={@id}
      class={[
        "hub-glass rounded-2xl border border-[color:var(--hub-border)] bg-[var(--hub-card)] p-4 shadow-[0_18px_36px_-26px_var(--hub-shadow)] sm:p-5",
        @class
      ]}
    >
      <div class="flex items-start justify-between gap-3">
        <div class="flex min-w-0 items-center gap-2.5">
          <span
            :if={@icon}
            class="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg border border-[color:var(--hub-border)] bg-[var(--hub-surface)] text-[var(--hub-secondary)]"
          >
            <.icon name={@icon} class="h-4 w-4" />
          </span>
          <div class="min-w-0">
            <p class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--hub-accent-2)]">
              <%= @kicker %>
            </p>
            <h2 class="font-display truncate text-lg text-[var(--hub-text)]"><%= @title %></h2>
          </div>
        </div>
        <div :if={@actions != []} class="flex shrink-0 items-center gap-1">
          <%= render_slot(@actions) %>
        </div>
      </div>
      <div class="mt-4">
        <%= render_slot(@inner_block) %>
      </div>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, default: "—"
  attr :hint, :string, default: nil

  defp hub_stat(assigns) do
    ~H"""
    <div class="min-w-0 rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] p-3">
      <p class="truncate text-[11px] text-[var(--hub-muted)]"><%= @label %></p>
      <p class="mt-1.5 text-lg font-semibold leading-none text-[var(--hub-text)]"><%= @value %></p>
      <p :if={@hint} class="mt-1.5 truncate text-[11px] text-[var(--hub-muted)]"><%= @hint %></p>
    </div>
    """
  end

  attr :current_scope, :any, default: nil
  attr :finance, :map, default: nil
  attr :scope, :string, default: "personal"
  attr :household, :any, default: nil

  def finance_card(assigns) do
    ~H"""
    <.fin_card class="flex h-full flex-col">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--hub-accent-2)]">
            Finance<%= if @scope == "household" && @household, do: " · #{@household.name}" %>
          </p>
          <h2 class="font-display text-2xl text-[var(--fin-text)]">Your money, at a glance</h2>
        </div>
        <div
          :if={@household}
          role="group"
          aria-label="Finance scope"
          class="inline-flex rounded-lg border border-[color:var(--hub-border)] bg-[var(--hub-surface)] p-0.5"
        >
          <button
            :for={{scope, label} <- [{"personal", "Personal"}, {"household", "Household"}]}
            type="button"
            phx-click="set_finance_scope"
            phx-value-scope={scope}
            aria-pressed={to_string(scope == @scope)}
            class={stats_toggle_class(scope == @scope)}
          >
            <%= label %>
          </button>
        </div>
      </div>

      <%= cond do %>
        <% is_nil(@current_scope) -> %>
          <.card_empty_state
            message="Sign in to see your balances and this month's spending."
            href={~p"/login"}
            action="Sign in"
          />
        <% is_nil(@finance) or @finance.accounts_count == 0 -> %>
          <.card_empty_state
            message="No accounts yet. Add one to see your balance and spending here."
            href={~p"/finance"}
            action="Add an account"
          />
        <% true -> %>
          <div class="mt-5 grid grid-cols-2 gap-3">
            <.hub_stat
              label="Total balance"
              value={money_totals(@finance.balance)}
              hint={"#{@finance.accounts_count} active #{if @finance.accounts_count == 1, do: "account", else: "accounts"}"}
            />
            <.hub_stat
              label="Spent this month"
              value={money_totals(@finance.month_spent)}
              hint={"Income #{money_totals(@finance.month_income)}"}
            />
          </div>
          <div :if={@finance.budget_remaining_pct} class="mt-4">
            <div class="flex items-center justify-between text-[11px] text-[var(--hub-muted)]">
              <span>Budget left this month</span>
              <span class={tone_class("income", :text)}><%= money_totals(@finance.budget_remaining) %></span>
            </div>
            <div class="mt-1.5 h-1.5 overflow-hidden rounded-full bg-[var(--hub-surface)]">
              <div
                class={["h-full rounded-full", tone_class(budget_bar_tone(@finance.budget_remaining_pct), :bar)]}
                style={"width: #{@finance.budget_remaining_pct}%"}
              >
              </div>
            </div>
          </div>
      <% end %>

      <div class="mt-auto pt-5">
        <a
          href={if @current_scope, do: ~p"/finance", else: ~p"/login"}
          class="inline-flex items-center gap-1 rounded-lg px-2 py-1.5 text-sm font-semibold text-[var(--fin-accent)] transition hover:bg-[var(--fin-surface)] hover:text-[var(--hub-accent-2)]"
        >
          Open Finance <.icon name="hero-arrow-right" class="h-4 w-4" />
        </a>
      </div>
    </.fin_card>
    """
  end

  defp budget_bar_tone(pct) when pct <= 10, do: "expense"
  defp budget_bar_tone(pct) when pct <= 30, do: "review"
  defp budget_bar_tone(_pct), do: "income"

  attr :message, :string, required: true
  attr :href, :string, default: nil
  attr :action, :string, default: nil

  defp card_empty_state(assigns) do
    ~H"""
    <div class="mt-5 rounded-xl border border-dashed border-[color:var(--hub-accent)]/20 bg-[color:var(--hub-accent)]/5 px-4 py-4">
      <p class="text-sm text-[var(--hub-muted)]"><%= @message %></p>
      <a
        :if={@href}
        href={@href}
        class="mt-2 inline-flex items-center gap-1 text-sm font-semibold text-[var(--hub-secondary)] transition hover:text-[var(--hub-accent-2)]"
      >
        <%= @action %> <.icon name="hero-arrow-right" class="h-4 w-4" />
      </a>
    </div>
    """
  end

  attr :variant, :string, required: true, values: ~w(creator developer)
  attr :current_scope, :any, default: nil
  attr :developer, :any, required: true
  attr :github_form, :any, required: true
  attr :github_editing, :boolean, default: false

  def role_stats_card(assigns) do
    ~H"""
    <section class="hub-glass flex h-full flex-col rounded-2xl p-5 sm:p-6">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p class="text-[10px] font-semibold uppercase tracking-[0.16em] text-[var(--hub-accent-2)]">
            <%= if @variant == "creator", do: "Creator stats", else: "Developer stats" %>
          </p>
          <h2 class="font-display text-2xl text-[var(--hub-text)]">
            <%= if @variant == "creator", do: "Your reach", else: "Your code activity" %>
          </h2>
        </div>
        <div
          role="group"
          aria-label="Stats view"
          class="inline-flex rounded-lg border border-[color:var(--hub-border)] bg-[var(--hub-surface)] p-0.5"
        >
          <button
            :for={variant <- stats_variants()}
            type="button"
            phx-click="set_stats_variant"
            phx-value-variant={variant}
            aria-pressed={to_string(variant == @variant)}
            class={stats_toggle_class(variant == @variant)}
          >
            <%= String.capitalize(variant) %>
          </button>
        </div>
      </div>

      <%= if @variant == "creator" do %>
        <div class="mt-5 flex items-center gap-3 rounded-xl border border-dashed border-[color:var(--hub-accent)]/20 bg-[color:var(--hub-accent)]/5 px-4 py-4">
          <span class="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-[var(--hub-surface)] text-xs font-bold text-[var(--hub-muted)]">
            f
          </span>
          <div class="min-w-0">
            <p class="text-sm font-semibold text-[var(--hub-text)]">Facebook stats are coming soon</p>
            <p class="text-[11px] text-[var(--hub-muted)]">
              Followers, video views and interactions will show here once the Meta integration lands.
            </p>
          </div>
        </div>
      <% else %>
        <.async_result :let={developer} assign={@developer}>
          <:loading>
            <div class="mt-5 grid grid-cols-3 gap-3" aria-busy="true">
              <.hub_stat label="Repositories" value="…" />
              <.hub_stat label="Contributions" value="…" hint="Last 12 months" />
              <.hub_stat label="Last activity" value="…" />
            </div>
          </:loading>
          <:failed>
            <.card_empty_state message="GitHub stats are unavailable right now." />
          </:failed>
          <%= case {developer, @github_editing} do %>
            <% {:signed_out, _} -> %>
              <.card_empty_state
                message="Sign in to link your GitHub account."
                href={~p"/login"}
                action="Sign in"
              />
            <% {:not_linked, _} -> %>
              <.github_link_form form={@github_form} linked={false} />
            <% {_linked, true} -> %>
              <.github_link_form form={@github_form} linked={true} />
            <% {{_login, {:ok, stats}}, _} -> %>
              <div class="mt-5 grid grid-cols-3 gap-3">
                <.hub_stat label="Repositories" value={to_string(stats.public_repos)} hint="Public" />
                <.hub_stat
                  label="Contributions"
                  value={to_string(stats.contributions_last_year)}
                  hint="Last 12 months"
                />
                <.hub_stat label="Last activity" value={last_active_label(stats.last_active_on)} />
              </div>
              <.github_identity login={stats.login} />
            <% {{login, {:error, :not_found}}, _} -> %>
              <.card_empty_state message={"GitHub user @#{login} was not found."} />
              <.github_identity login={login} />
            <% {{login, _error}, _} -> %>
              <.card_empty_state message="GitHub stats are unavailable right now. Try again in a few minutes." />
              <.github_identity login={login} />
          <% end %>
        </.async_result>
      <% end %>
    </section>
    """
  end

  attr :login, :string, required: true

  defp github_identity(assigns) do
    ~H"""
    <div class="mt-auto flex flex-wrap items-center justify-between gap-2 pt-5 text-sm">
      <span class="text-[var(--hub-muted)]">
        @<%= @login %>
        <button
          type="button"
          phx-click="edit_github"
          class="ml-1 font-semibold text-[var(--hub-secondary)] transition hover:text-[var(--hub-accent-2)]"
        >
          Change
        </button>
      </span>
      <a
        href={~p"/contributions"}
        class="inline-flex items-center gap-1 font-semibold text-[var(--hub-secondary)] transition hover:text-[var(--hub-accent-2)]"
      >
        Details <.icon name="hero-arrow-right" class="h-4 w-4" />
      </a>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :linked, :boolean, default: false

  defp github_link_form(assigns) do
    ~H"""
    <.form for={@form} id="github-link-form" phx-submit="save_github" class="mt-5">
      <label for="github-username" class="text-sm text-[var(--hub-muted)]">
        Link your GitHub username to show your public activity here.
      </label>
      <div class="mt-2 flex flex-wrap gap-2">
        <input
          id="github-username"
          type="text"
          name={@form[:github_username].name}
          value={@form[:github_username].value}
          placeholder="your-github-login"
          autocomplete="off"
          spellcheck="false"
          class="min-w-0 flex-1 rounded-lg border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-3 py-2 text-sm text-[var(--hub-text)] placeholder:text-[var(--hub-muted)] focus:border-[color:var(--hub-accent)] focus:outline-none focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
        />
        <button type="submit" class="btn btn-primary btn-sm">
          <%= if @linked, do: "Save", else: "Connect GitHub" %>
        </button>
        <button :if={@linked} type="button" phx-click="cancel_github" class="btn btn-secondary btn-sm">
          Cancel
        </button>
      </div>
      <p
        :for={{msg, _} <- @form[:github_username].errors}
        class={["mt-2 text-xs", tone_class("expense", :text)]}
      >
        <%= msg %>
      </p>
      <p :if={@linked} class="mt-2 text-xs text-[var(--hub-muted)]">Leave it empty to unlink.</p>
    </.form>
    """
  end

  defp last_active_label(nil), do: "—"

  defp last_active_label(%Date{} = date) do
    case Date.diff(Date.utc_today(), date) do
      0 -> "Today"
      1 -> "Yesterday"
      days when days < 7 -> "#{days} days ago"
      _ -> Calendar.strftime(date, "%b %-d")
    end
  end

  attr :current_scope, :any, default: nil
  attr :focus, :map, default: nil
  attr :form, :any, default: nil
  attr :selected_date, :any, default: nil

  def tasks_panel(assigns) do
    ~H"""
    <.hub_card id="tasks" kicker="Focus" title="Tasks" icon="hero-check" class="h-full sm:p-6">
      <:actions>
        <span
          :if={@focus}
          class="rounded-full border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-2.5 py-1 text-xs text-[var(--hub-muted)]"
        >
          <%= @focus.open_count %> open
        </span>
      </:actions>

      <%= if is_nil(@current_scope) do %>
        <.card_empty_state message="Sign in to see your IziOffice tasks." href={~p"/login"} action="Sign in" />
      <% else %>
        <.form for={@form} id="quick-add-task" phx-submit="quick_add_task" class="flex gap-2">
          <input
            type="text"
            name={@form[:title].name}
            value={@form[:title].value}
            placeholder={"Add a task for #{task_day_label(@selected_date)}…"}
            aria-label="New task title"
            autocomplete="off"
            maxlength="140"
            class="min-w-0 flex-1 rounded-lg border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-3 py-2 text-sm text-[var(--hub-text)] placeholder:text-[var(--hub-muted)] focus:border-[color:var(--hub-accent)] focus:outline-none focus:ring-2 focus:ring-[color:var(--hub-accent)]/30"
          />
          <button type="submit" class="btn btn-primary btn-sm">Add</button>
        </.form>
        <p :for={{msg, _} <- @form[:title].errors} class={["mt-2 text-xs", tone_class("expense", :text)]}>
          Title <%= msg %>
        </p>

        <%= if @focus.open_count == 0 do %>
          <.card_empty_state message="Nothing open. Add a task above or plan your week in IziOffice." />
        <% else %>
          <div class="mt-4 space-y-4">
            <.task_group :if={@focus.overdue != []} label="Overdue" tone="expense" tasks={@focus.overdue} />
            <.task_group :if={@focus.today != []} label="Today" tone="income" tasks={@focus.today} />
            <.task_group :if={@focus.up_next != []} label="Up next" tone="muted" tasks={@focus.up_next} />
          </div>
        <% end %>

        <a
          href={~p"/office"}
          class="mt-4 inline-flex items-center gap-1 text-sm font-semibold text-[var(--hub-secondary)] transition hover:text-[var(--hub-accent-2)]"
        >
          Open IziOffice <.icon name="hero-arrow-right" class="h-4 w-4" />
        </a>
      <% end %>
    </.hub_card>
    """
  end

  attr :label, :string, required: true
  attr :tone, :string, required: true
  attr :tasks, :list, required: true

  defp task_group(assigns) do
    ~H"""
    <section>
      <p class={["text-[10px] font-semibold uppercase tracking-[0.16em]", tone_class(@tone, :text)]}>
        <%= @label %>
      </p>
      <ul class="mt-2 divide-y divide-[color:var(--hub-border)] rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)]">
        <li :for={%{task: task, date: date} <- @tasks} id={"focus-task-#{task.id}"} class="flex items-center gap-3 px-3 py-2.5">
          <span class={["h-2.5 w-2.5 shrink-0 rounded-full", stage_dot_class(task.status)]} title={stage_label(task.status)}></span>
          <div class="min-w-0 flex-1">
            <p class="truncate text-sm font-medium text-[var(--hub-text)]"><%= task.title %></p>
            <p class="truncate text-[11px] text-[var(--hub-muted)]">
              <%= task.project.name %><%= if date, do: " · #{Calendar.strftime(date, "%b %-d")}" %> · <%= stage_label(task.status) %>
            </p>
          </div>
          <button
            :if={next = Core.Office.next_status(task.status)}
            type="button"
            phx-click="advance_task"
            phx-value-id={task.id}
            title={"Move to #{stage_label(next)}"}
            class="shrink-0 rounded-lg border border-[color:var(--hub-border)] px-2 py-1 text-[11px] font-semibold text-[var(--hub-secondary)] transition hover:border-[color:var(--hub-accent)]/50 hover:text-[var(--hub-accent-2)]"
          >
            → <%= stage_label(next) %>
          </button>
        </li>
      </ul>
    </section>
    """
  end

  defp task_day_label(nil), do: "today"
  defp task_day_label(%Date{} = date), do: Calendar.strftime(date, "%b %-d")

  # Same stage colors as IziOffice's board.
  defp stage_dot_class("queue"), do: "bg-[var(--hub-accent)]"
  defp stage_dot_class("wip"), do: "bg-[var(--tone-info)]"
  defp stage_dot_class("qa"), do: "bg-[var(--tone-review)]"
  defp stage_dot_class("release"), do: "bg-[var(--tone-income)]"
  defp stage_dot_class(_), do: "bg-[var(--hub-muted)]"

  defp stage_label("queue"), do: "Queue"
  defp stage_label("wip"), do: "WIP"
  defp stage_label("qa"), do: "QA"
  defp stage_label("release"), do: "Release"
  defp stage_label(other), do: other

  attr :month, Date, required: true
  attr :days, :list, required: true
  attr :weekdays, :list, required: true
  attr :selected_date, :any, default: nil
  attr :agenda, :map, default: nil

  def calendar_card(assigns) do
    ~H"""
    <.hub_card
      id="calendar"
      kicker="Calendar"
      title={Calendar.strftime(@month, "%B %Y")}
      icon="hero-calendar-days"
    >
      <:actions>
        <button
          type="button"
          phx-click="prev_calendar_month"
          aria-label="Previous month"
          class="grid h-8 w-8 place-items-center rounded-lg text-[var(--hub-secondary)] transition hover:bg-[var(--hub-surface)]"
        >
          <.icon name="hero-arrow-left" class="h-3.5 w-3.5" />
        </button>
        <button
          type="button"
          phx-click="next_calendar_month"
          aria-label="Next month"
          class="grid h-8 w-8 place-items-center rounded-lg text-[var(--hub-secondary)] transition hover:bg-[var(--hub-surface)]"
        >
          <.icon name="hero-arrow-right" class="h-3.5 w-3.5" />
        </button>
      </:actions>
      <div class="grid grid-cols-7 text-center text-[10px] font-semibold uppercase tracking-wide text-[var(--hub-muted)]">
        <span :for={weekday <- @weekdays}><%= weekday %></span>
      </div>
      <div class="mt-1 grid grid-cols-7">
        <button
          :for={day <- @days}
          type="button"
          phx-click="select_calendar_date"
          phx-value-date={Date.to_iso8601(day.date)}
          aria-pressed={to_string(day.selected?)}
          aria-label={calendar_day_aria(day)}
          class={calendar_day_class(day)}
        >
          <span><%= day.label %></span>
          <span :if={day.total_count > 0} class={["h-1 w-1 rounded-full", calendar_dot_class(day.total_count)]}></span>
        </button>
      </div>
      <div class="mt-2 border-t border-[color:var(--hub-border)] pt-2">
        <p class="text-[11px] text-[var(--hub-muted)]">
          <%= if @selected_date, do: Calendar.strftime(@selected_date, "%a, %b %-d"), else: "Select a date to see its agenda" %>
        </p>
        <div :if={@agenda} id="calendar-agenda" class="mt-2 space-y-1.5">
          <p :if={@agenda.tasks == [] and @agenda.entries == []} class="text-xs text-[var(--hub-muted)]">
            Nothing planned.
          </p>
          <div :for={task <- @agenda.tasks} class="flex items-center gap-2 text-xs">
            <span class={["h-2 w-2 shrink-0 rounded-full", stage_dot_class(task.status)]}></span>
            <span class="min-w-0 flex-1 truncate text-[var(--hub-text)]"><%= task.title %></span>
            <span class="shrink-0 text-[var(--hub-muted)]"><%= task.project.name %></span>
          </div>
          <div :for={entry <- @agenda.entries} class="flex items-center gap-2 text-xs">
            <span class={["h-2 w-2 shrink-0 rotate-45 rounded-[2px]", entry_dot_class(entry.kind)]}></span>
            <span class="min-w-0 flex-1 truncate text-[var(--hub-text)]"><%= entry.title %></span>
            <span class="shrink-0 text-[var(--hub-muted)]"><%= String.capitalize(entry.kind) %></span>
          </div>
        </div>
      </div>
    </.hub_card>
    """
  end

  defp calendar_day_aria(%{total_count: 0} = day), do: Calendar.strftime(day.date, "%B %-d")

  defp calendar_day_aria(day),
    do: "#{Calendar.strftime(day.date, "%B %-d")}, #{day.total_count} planned"

  # Office's busy-ness scale: green 1-2, gold 3-4, red 5+.
  defp calendar_dot_class(count) when count <= 2, do: "bg-[var(--tone-income)]"
  defp calendar_dot_class(count) when count <= 4, do: "bg-[var(--tone-review)]"
  defp calendar_dot_class(_count), do: "bg-[var(--tone-expense)]"

  defp entry_dot_class("release"), do: "bg-[var(--tone-income)]"
  defp entry_dot_class("deadline"), do: "bg-[var(--tone-expense)]"
  defp entry_dot_class("note"), do: "bg-[var(--tone-info)]"
  defp entry_dot_class(_), do: "bg-[var(--hub-accent)]"

  def music_card(assigns) do
    ~H"""
    <.hub_card id="music" kicker="Listening" title="Music" icon="hero-musical-note">
      <div class="flex items-center gap-3">
        <div class="h-12 w-12 shrink-0 rounded-lg border border-[color:var(--hub-border)] bg-[linear-gradient(135deg,var(--hub-accent),var(--hub-surface))]">
        </div>
        <div class="min-w-0">
          <p class="truncate text-sm font-semibold text-[var(--hub-text)]">Nothing playing</p>
          <p class="text-[11px] text-[var(--hub-muted)]">Connect a music service</p>
        </div>
      </div>
      <div class="mt-3 h-1 overflow-hidden rounded-full bg-[var(--hub-surface)]"></div>
      <div class="mt-3 flex items-center justify-center gap-2">
        <button
          :for={{label, glyph} <- [{"Previous track", "⏮"}, {"Play", "▶"}, {"Next track", "⏭"}]}
          type="button"
          disabled
          aria-label={label}
          title="Music connection coming soon"
          class="grid h-9 w-9 cursor-not-allowed place-items-center rounded-full border border-[color:var(--hub-border)] text-sm text-[var(--hub-muted)] opacity-70"
        >
          <span aria-hidden="true"><%= glyph %></span>
        </button>
      </div>
    </.hub_card>
    """
  end

  attr :current_scope, :any, default: nil

  def library_shortcuts(assigns) do
    ~H"""
    <.hub_card id="library" kicker="Library" title="Books & courses" icon="hero-book-open">
      <div class="grid gap-2">
        <a
          href={if @current_scope, do: ~p"/notebooks", else: ~p"/login"}
          class="group flex items-center gap-3 rounded-xl border border-[color:var(--hub-border)] bg-[var(--hub-surface)] px-3 py-2.5 transition hover:border-[color:var(--hub-accent)]"
        >
          <.icon name="hero-book-open" class="h-4 w-4 shrink-0 text-[var(--hub-secondary)]" />
          <span class="min-w-0 flex-1">
            <span class="block text-sm font-semibold text-[var(--hub-text)]">Books</span>
            <span class="block text-[11px] text-[var(--hub-muted)]">PDF library &amp; notebooks</span>
          </span>
          <.icon
            name="hero-arrow-right"
            class="h-4 w-4 shrink-0 text-[var(--hub-muted)] transition group-hover:translate-x-0.5 group-hover:text-[var(--hub-secondary)]"
          />
        </a>
        <div class="flex items-center gap-3 rounded-xl border border-dashed border-[color:var(--hub-border)] px-3 py-2.5">
          <.icon name="hero-academic-cap" class="h-4 w-4 shrink-0 text-[var(--hub-muted)]" />
          <span class="min-w-0 flex-1">
            <span class="block text-sm font-semibold text-[var(--hub-text)]">Courses</span>
            <span class="block text-[11px] text-[var(--hub-muted)]">Track what you're learning</span>
          </span>
          <span class="shrink-0 rounded-full bg-[color:var(--hub-accent)]/20 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-[var(--hub-accent-2)]">
            Soon
          </span>
        </div>
      </div>
    </.hub_card>
    """
  end

  def gmail_preview(assigns) do
    ~H"""
    <.hub_card id="gmail" kicker="Inbox" title="Gmail" icon="hero-envelope">
      <ul class="space-y-2" aria-label="Inbox preview">
        <li
          :for={width <- ["w-3/4", "w-2/3", "w-1/2"]}
          class="flex items-center gap-3 rounded-lg px-1 py-1.5"
          aria-hidden="true"
        >
          <span class="h-7 w-7 shrink-0 rounded-full bg-[var(--hub-surface)]"></span>
          <span class="flex-1 space-y-1.5">
            <span class={["block h-2 rounded-full bg-[var(--hub-surface)]", width]}></span>
            <span class="block h-2 w-full rounded-full bg-[color:var(--hub-surface)]/60"></span>
          </span>
        </li>
      </ul>
      <p class="mt-3 border-t border-[color:var(--hub-border)] pt-2 text-[11px] text-[var(--hub-muted)]">
        Connect Gmail to preview recent mail.
      </p>
    </.hub_card>
    """
  end

  defp stats_toggle_class(true) do
    "rounded-md bg-[var(--hub-primary)] px-2.5 py-1 text-xs font-semibold text-[var(--hub-on-primary)]"
  end

  defp stats_toggle_class(false) do
    "rounded-md px-2.5 py-1 text-xs font-semibold text-[var(--hub-muted)] transition hover:text-[var(--hub-text)]"
  end

  defp calendar_day_class(day) do
    base =
      "flex h-8 w-full flex-col items-center justify-center gap-0.5 rounded-lg text-xs leading-none transition-colors"

    cond do
      day.selected? ->
        base <> " bg-[var(--hub-primary)] font-semibold text-[var(--hub-on-primary)]"

      day.in_month? ->
        base <> " text-[var(--hub-text)] hover:bg-[var(--hub-surface)]"

      true ->
        base <> " text-[color:var(--hub-muted)]/40 hover:bg-[var(--hub-surface)]"
    end
  end
end

defmodule CoreWeb.FinanceComponents do
  @moduledoc false
  use CoreWeb, :html

  alias Core.Accounts
  alias Core.Finance.{Account, Transaction}

  @default_currency "DOP"

  @networth_category_order ["cash", "investments", "other_assets", "liabilities"]

  @networth_category_meta %{
    "cash" => %{label: "Cash & bank", icon: "hero-banknotes", tone: "income"},
    "investments" => %{label: "Investments", icon: "hero-chart-bar-square", tone: "budget"},
    "other_assets" => %{label: "Other assets", icon: "hero-plus-circle", tone: "review"},
    "liabilities" => %{label: "Liabilities", icon: "hero-arrow-trending-down", tone: "expense"}
  }

  def finance_section_header(assigns) do
    ~H"""
    <section>
      <.fin_card padded={false} class="px-5 py-5 sm:px-6">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div class="space-y-2">
            <p class="text-[11px] font-semibold uppercase tracking-[0.24em] text-[color:var(--fin-muted)]"><%= greeting_date() %></p>
            <h1 class="font-display text-[1.55rem] tracking-tight text-[color:var(--fin-text)]">
              <%= active_section_title(@active_section, @pending_review_count) %>
            </h1>
            <p :if={active_section_subtitle(@active_section)} class="max-w-2xl text-sm leading-6 text-[color:var(--fin-muted)]">
              <%= active_section_subtitle(@active_section) %>
            </p>
          </div>

          <div class="flex flex-wrap items-center justify-end gap-2.5">
            <div class="inline-flex items-center gap-2 rounded-full border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-1 py-1 shadow-[0_16px_32px_-24px_var(--fin-glass-shadow)]">
              <button
                type="button"
                phx-click="set_ownership_scope"
                phx-value-scope="personal"
                aria-label="Personal finance scope"
                title="Personal finance scope"
                class={[
                  "inline-flex h-9 items-center gap-2 rounded-full px-3.5 text-sm font-semibold transition",
                  @ownership_scope == "personal" && "bg-[#465fff] text-[#ffffff] shadow-sm",
                  @ownership_scope != "personal" && "text-[color:var(--fin-muted)] hover:bg-[color:var(--fin-surface)] hover:text-[color:var(--fin-text)]"
                ]}
              >
                <.icon name="hero-user" class="h-4 w-4" />
                Personal
              </button>
              <button
                type="button"
                phx-click={household_toggle_event(@households)}
                phx-value-scope="household"
                phx-value-panel="household"
                aria-label={household_scope_aria_label(@households)}
                title={household_scope_title(@households)}
                class={[
                  "inline-flex h-9 items-center gap-2 rounded-full px-3.5 text-sm font-semibold transition",
                  @ownership_scope == "household" && "bg-[#465fff] text-[#ffffff] shadow-sm",
                  @ownership_scope != "household" && "text-[color:var(--fin-muted)] hover:bg-[color:var(--fin-surface)] hover:text-[color:var(--fin-text)]"
                ]}
              >
                <.icon :if={household_scope_available?(@households)} name="hero-home" class="h-4 w-4" />
                <%= if household_scope_available?(@households), do: "Household", else: "+ Household" %>
              </button>
            </div>

            <.household_picker :if={@households != []} households={@households} selected_household_id={@selected_household_id} />

            <button
              type="button"
              phx-click="open_household_panel"
              aria-label="Add household"
              title="Add household"
              class="inline-flex h-10 w-10 items-center justify-center rounded-xl border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] text-[color:var(--fin-muted)] transition hover:bg-[color:var(--fin-card)] hover:text-[color:var(--fin-text)]"
            >
              <.icon name="hero-plus" class="h-4 w-4" />
            </button>
          </div>
        </div>
      </.fin_card>
    </section>
    """
  end

  def finance_dashboard_header(assigns) do
    ~H"""
    <section>
      <.fin_card padded={false} class="px-6 py-6 sm:px-8">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-[12px] font-semibold uppercase tracking-[0.24em] text-[color:var(--fin-muted)]"><%= greeting_date() %> · this month</p>
            <h1 class="mt-1 text-xl font-display text-[color:var(--fin-text)]"><%= greeting_headline(@current_scope.user) %></h1>
          </div>

          <div class="flex flex-wrap items-center gap-2.5">
            <div class="inline-flex items-center gap-1 rounded-full border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-1 py-1 shadow-[0_16px_32px_-24px_var(--fin-glass-shadow)]">
              <button
                type="button"
                phx-click="set_ownership_scope"
                phx-value-scope="personal"
                aria-label="Personal finance scope"
                title="Personal finance scope"
                class={[
                  "inline-flex h-9 items-center gap-2 rounded-full px-3.5 text-sm font-semibold transition",
                  @ownership_scope == "personal" && "bg-[#465fff] text-[#ffffff] shadow-sm",
                  @ownership_scope != "personal" && "text-[color:var(--fin-muted)] hover:bg-[color:var(--fin-surface)] hover:text-[color:var(--fin-text)]"
                ]}
              >
                <.icon name="hero-user" class="h-4 w-4" />
                Personal
              </button>
              <button
                type="button"
                phx-click={household_toggle_event(@households)}
                phx-value-scope="household"
                phx-value-panel="household"
                aria-label={household_scope_aria_label(@households)}
                title={household_scope_title(@households)}
                class={[
                  "inline-flex h-9 items-center gap-2 rounded-full px-3.5 text-sm font-semibold transition",
                  @ownership_scope == "household" && "bg-[#465fff] text-[#ffffff] shadow-sm",
                  @ownership_scope != "household" && "text-[color:var(--fin-muted)] hover:bg-[color:var(--fin-surface)] hover:text-[color:var(--fin-text)]"
                ]}
              >
                <.icon :if={household_scope_available?(@households)} name="hero-home" class="h-4 w-4" />
                <%= if household_scope_available?(@households), do: "Household", else: "+ Household" %>
              </button>
            </div>

            <.household_picker :if={@households != []} households={@households} selected_household_id={@selected_household_id} />

            <button
              type="button"
              phx-click="open_household_panel"
              aria-label="Add household"
              title="Add household"
              class="inline-flex h-10 w-10 items-center justify-center rounded-xl border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] text-[color:var(--fin-muted)] transition hover:bg-[color:var(--fin-card)] hover:text-[color:var(--fin-text)]"
            >
              <.icon name="hero-plus" class="h-4 w-4" />
            </button>

            <button
              type="button"
              phx-click="open_focus_panel"
              phx-value-panel="transaction"
              aria-label="Add transaction"
              title="Add transaction"
              class="inline-flex h-10 items-center gap-1.5 rounded-xl border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-4 text-sm font-semibold text-[color:var(--fin-text)] shadow-[0_16px_32px_-24px_var(--fin-glass-shadow)] transition hover:border-[color:var(--fin-border)] hover:bg-[color:var(--fin-surface)]"
            >
              <.icon name="hero-plus" class="h-4 w-4" /> Add transaction
            </button>
          </div>
        </div>

      </.fin_card>
    </section>
    """
  end

  @doc """
  "This month's budget" mini card for the overview bottom row — spent vs
  remaining with a depleting bar (budget bars deplete; goal bars fill).
  """
  attr :budget_statuses, :list, required: true
  attr :budget_spent_totals, :list, required: true
  attr :budget_remaining_totals, :list, required: true
  attr :budget_usage_pct, :any, required: true

  def budget_mini_card(assigns) do
    ~H"""
    <.fin_card>
      <div class="flex items-center justify-between gap-3">
        <div>
          <p class="text-[11px] font-semibold uppercase tracking-[0.22em] text-[color:var(--fin-muted)]">Budget</p>
          <h2 class="mt-2 text-lg font-semibold text-[color:var(--fin-text)]">This month</h2>
        </div>
        <button
          type="button"
          phx-click="open_focus_panel"
          phx-value-panel="budget"
          aria-label="Create budget"
          title="Create budget"
          class="text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--fin-accent)] transition hover:text-[color:var(--fin-text)]"
        >
          + Budget
        </button>
      </div>

      <div class="mt-5 flex items-center justify-between gap-4">
        <div>
          <p class="text-xs text-[color:var(--fin-muted)]">Spent</p>
          <p class="mt-1 text-lg font-mono font-semibold text-[var(--tone-expense)]"><%= money_totals(@budget_spent_totals) %></p>
        </div>
        <div class="text-right">
          <p class="text-xs text-[color:var(--fin-muted)]">Remaining</p>
          <p class="mt-1 text-lg font-mono font-semibold text-[var(--tone-income)]"><%= money_totals(@budget_remaining_totals) %></p>
        </div>
      </div>

      <div class="mt-4 h-2 w-full overflow-hidden rounded-full bg-[color:var(--fin-surface)]">
        <div
          class={["h-full rounded-full", tone_class(overall_budget_tone(@budget_statuses), :bar)]}
          style={"width: #{budget_remaining_pct(@budget_usage_pct)}%"}
        >
        </div>
      </div>

      <p class="mt-2.5 text-[11px] text-[color:var(--fin-muted)]">
        <%= if @budget_statuses == [],
          do: "No active budgets this month.",
          else: "#{round(@budget_usage_pct)}% of this month's budgets used." %>
      </p>
    </.fin_card>
    """
  end

  @doc """
  TailAdmin "Total Balance" hero card: currency + month selectors, big
  balance with a "than last month" delta, sparkline, primary-account line,
  and Transfer / Received / + actions.
  """
  attr :hero, :map, required: true

  def balance_hero_card(assigns) do
    sparkline_payload =
      chart_payload(%{
        chart: %{
          type: "area",
          height: 90,
          sparkline: %{enabled: true},
          fontFamily: "inherit"
        },
        series: [%{name: "Balance", data: Enum.map(assigns.hero.sparkline, &Float.round(&1, 2))}],
        colors: ["#465fff"],
        stroke: %{curve: "smooth", width: 2},
        fill: %{
          type: "gradient",
          gradient: %{opacityFrom: 0.25, opacityTo: 0.02, shadeIntensity: 0}
        },
        tooltip: %{enabled: false}
      })

    assigns = assign(assigns, :sparkline_payload, sparkline_payload)

    ~H"""
    <.fin_card class="flex h-full flex-col">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 class="text-lg font-semibold tracking-tight text-[color:var(--fin-text)]">Total Balance</h2>
          <p class="mt-1 text-sm text-[color:var(--fin-muted)]">Overview of your current funds</p>
        </div>
        <div class="flex items-center gap-1.5">
          <form phx-change="select_hero_currency">
            <select
              name="currency"
              class="rounded-lg border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] px-2 py-1 text-[11px] font-semibold text-[color:var(--fin-text)] outline-none transition focus:border-[var(--fin-accent)]"
            >
              <option :for={currency <- @hero.currencies} value={currency} selected={currency == @hero.currency}>
                <%= currency %>
              </option>
            </select>
          </form>
          <form phx-change="select_hero_month">
            <select
              name="month"
              class="rounded-lg border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] px-2 py-1 text-[11px] font-semibold text-[color:var(--fin-text)] outline-none transition focus:border-[var(--fin-accent)]"
            >
              <option :for={{label, value} <- @hero.month_options} value={value} selected={value == @hero.month}>
                <%= label %>
              </option>
            </select>
          </form>
        </div>
      </div>

      <div class="mt-6">
        <p class="font-mono text-[2.1rem] font-semibold leading-none tracking-[-0.03em] text-[color:var(--fin-text)]">
          <%= money(@hero.balance, @hero.currency) %>
        </p>
        <.delta_line delta={@hero.balance_delta} class="mt-2.5" />
      </div>

      <div id="hero-sparkline" phx-hook="ApexChart" data-chart={@sparkline_payload} class="mt-4" style="min-height: 90px">
        <div data-chart-target phx-update="ignore" id="hero-sparkline-target"></div>
      </div>

      <div class="mt-5 flex items-center justify-between gap-2 border-t border-dashed border-[color:var(--fin-border)] pt-4">
        <p class="min-w-0 truncate text-sm text-[color:var(--fin-muted)]">
          Primary Account:
          <span :if={@hero.primary_account} class="ml-1 font-mono font-semibold text-[color:var(--fin-text)]">
            •••• <%= account_card_mask(@hero.primary_account) %>
          </span>
          <span :if={!@hero.primary_account} class="ml-1 text-[color:var(--fin-muted)]">none yet</span>
        </p>
        <div class="flex shrink-0 items-center gap-1.5">
          <button
            :if={@hero.primary_account}
            type="button"
            id="hero-copy-account"
            phx-hook="CopyToClipboard"
            data-copy-value={"#{@hero.primary_account.name} •••• #{account_card_mask(@hero.primary_account)}"}
            data-copy-title="Copy account"
            aria-label="Copy account"
            title="Copy account"
            class="inline-flex h-7 w-7 items-center justify-center rounded-lg border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] text-[color:var(--fin-muted)] transition hover:bg-[color:var(--fin-surface)] hover:text-[color:var(--fin-text)] data-[copied]:border-[var(--fin-accent)] data-[copied]:text-[var(--fin-accent)]"
          >
            <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" class="h-3.5 w-3.5">
              <rect x="9" y="9" width="11" height="12" rx="2" />
              <path d="M5 15V5a2 2 0 0 1 2-2h8" />
            </svg>
          </button>
          <button
            type="button"
            phx-click="show_section"
            phx-value-section="accounts"
            class="whitespace-nowrap rounded-lg border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] px-2.5 py-1 text-[11px] font-semibold text-[color:var(--fin-text)] transition hover:bg-[color:var(--fin-surface)]"
          >
            See Details
          </button>
        </div>
      </div>

      <div class="mt-5 flex flex-wrap items-center gap-2.5">
        <button
          type="button"
          phx-click="open_focus_panel"
          phx-value-panel="transfer"
          aria-label="Record transfer"
          title="Record transfer"
          class="btn btn-primary btn-sm inline-flex items-center gap-1.5"
        >
          <.icon name="hero-arrow-trending-up" class="h-4 w-4" /> Transfer
        </button>
        <button
          type="button"
          phx-click="open_received"
          aria-label="Record received income"
          title="Record received income"
          class="btn btn-secondary btn-sm inline-flex items-center gap-1.5"
        >
          <.icon name="hero-arrow-trending-down" class="h-4 w-4" /> Received
        </button>
        <button
          type="button"
          phx-click="open_focus_panel"
          phx-value-panel="transaction"
          aria-label="Quick add transaction"
          title="Quick add transaction"
          class="btn btn-secondary btn-sm"
        >
          <.icon name="hero-plus" class="h-4 w-4" />
        </button>
      </div>
    </.fin_card>
    """
  end

  attr :delta, :any, required: true
  attr :class, :any, default: nil

  defp delta_line(assigns) do
    ~H"""
    <p :if={@delta} class={["flex items-center gap-1.5 text-sm font-medium", @class]}>
      <span class={[
        "inline-flex items-center gap-0.5 rounded-full px-1.5 py-0.5 text-xs font-semibold",
        @delta >= 0 && tone_class("income", :soft),
        @delta < 0 && tone_class("expense", :soft)
      ]}>
        <%= if @delta >= 0, do: "↑", else: "↓" %> <%= Float.round(abs(@delta / 1), 1) %>%
      </span>
      <span class="text-[color:var(--fin-muted)]">than last month</span>
    </p>
    <p :if={!@delta} class={["text-sm text-[color:var(--fin-muted)]", @class]}>No prior month to compare</p>
    """
  end

  @doc """
  TailAdmin stat tile: label, soft icon chip top-right, big value, and a
  "than last month" delta row (or a custom inner block, e.g. the saving-rate
  radial).

  `value` accepts either a pre-formatted string (single-currency values, e.g.
  `money/2`) or a raw list of `%{currency, amount}` totals (multi-currency,
  e.g. `net_worth_summary.net`). Multi-currency values render one currency per
  line instead of joining them into one string — a joined string wraps
  wherever the browser finds space, which lands mid-value (a stray currency
  symbol stranded before its own number); one `<p>` per currency means any
  wrap only ever falls between currencies, never inside one.
  """
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true
  attr :tone, :string, default: "muted"
  attr :delta, :any, default: nil
  attr :show_delta, :boolean, default: true
  slot :inner_block

  def stat_tile(assigns) do
    ~H"""
    <.fin_card class="flex h-full flex-col p-4">
      <div class="flex items-start justify-between gap-3">
        <p class="text-xs font-medium text-[color:var(--fin-muted)]"><%= @label %></p>
        <span class={["inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-xl", tone_class(@tone, :soft)]}>
          <.icon name={@icon} class="h-4 w-4" />
        </span>
      </div>
      <div class="mt-2.5 space-y-0.5 font-mono text-[1.35rem] font-semibold leading-tight tracking-[-0.03em] text-[color:var(--fin-text)]">
        <p :for={line <- stat_tile_value_lines(@value)} class="whitespace-nowrap"><%= line %></p>
      </div>
      <div class="mt-auto pt-3">
        <.delta_line :if={@show_delta} delta={@delta} />
        <%= render_slot(@inner_block) %>
      </div>
    </.fin_card>
    """
  end

  defp stat_tile_value_lines(value) when is_binary(value), do: [value]
  defp stat_tile_value_lines([]), do: [money(nil, @default_currency)]

  defp stat_tile_value_lines(totals) when is_list(totals) do
    totals
    |> sort_currency_totals()
    |> Enum.map(&money(&1.amount, &1.currency))
  end

  @doc """
  Small conic-gradient ring for the saving-rate tile — progress toward the
  saving goal (fills up, per the goal-bar convention).
  """
  attr :rate, :any, required: true
  attr :goal, :float, required: true

  def saving_rate_radial(assigns) do
    progress =
      case assigns.rate do
        nil -> 0.0
        rate -> min(max(rate / assigns.goal * 100, 0.0), 100.0)
      end

    note =
      case assigns.rate do
        nil -> "No income this month"
        rate when rate >= assigns.goal -> "Goal: #{round(assigns.goal)}% – met"
        rate -> "Goal: #{round(assigns.goal)}% – #{Float.round(assigns.goal - rate, 1)}% to go"
      end

    assigns = assign(assigns, progress: progress, note: note)

    ~H"""
    <div class="flex items-center gap-2.5">
      <span
        class="inline-block h-8 w-8 shrink-0 rounded-full"
        style={"background: conic-gradient(var(--fin-accent) #{@progress}%, var(--fin-surface) 0); -webkit-mask: radial-gradient(farthest-side, transparent calc(100% - 5px), #000 calc(100% - 4px)); mask: radial-gradient(farthest-side, transparent calc(100% - 5px), #000 calc(100% - 4px));"}
      >
      </span>
      <span class="text-sm text-[color:var(--fin-muted)]"><%= @note %></span>
    </div>
    """
  end

  attr :current, :string, required: true
  attr :scope, :string, required: true
  attr :bubble, :boolean, default: false

  def time_scope_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="set_time_scope"
      phx-value-scope={@scope}
      class={[
        @bubble && "rounded-full px-3 py-1.5 text-xs font-semibold transition",
        !@bubble && "rounded-full px-3 py-1.5 text-xs font-semibold transition",
        @current == @scope && @bubble && "bg-[#465fff] text-[#ffffff] shadow-[0_10px_20px_-16px_rgba(70,95,255,0.35)]",
        @current != @scope && @bubble && "text-[color:var(--fin-muted)] hover:bg-[color:var(--fin-surface)] hover:text-[color:var(--fin-text)]",
        @current == @scope && !@bubble && "bg-[#465fff] text-[#ffffff] shadow-sm",
        @current != @scope && !@bubble && "text-[color:var(--fin-muted)] hover:bg-[color:var(--fin-surface)] hover:text-[color:var(--fin-text)]"
      ]}
    >
      <%= time_scope_title(@scope) %>
    </button>
    """
  end

  attr :households, :list, required: true
  attr :selected_household_id, :string, default: nil

  def household_picker(assigns) do
    ~H"""
    <form phx-change="select_household">
      <label class="sr-only" for="household_id">Household</label>
      <select
        id="household_id"
        name="household_id"
        class="rounded-full border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-3.5 py-2 text-sm font-semibold text-[color:var(--fin-text)] shadow-[0_16px_32px_-24px_var(--fin-glass-shadow)]"
      >
        <option :for={household <- @households} value={household.id} selected={household.id == @selected_household_id}>
          <%= household.name %>
        </option>
      </select>
    </form>
    """
  end

  def household_panel(assigns) do
    ~H"""
    <section class="grid gap-4 lg:grid-cols-[0.92fr_1.08fr]">
      <div class="rounded-xl border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-5">
        <div>
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.22em] text-[color:var(--fin-muted)]">Households</p>
            <h3 class="mt-2 text-xl font-semibold tracking-tight text-[color:var(--fin-text)]">Create or switch scope</h3>
          </div>
        </div>

        <.form for={@household_form} phx-submit="create_household" class="mt-5 space-y-4">
          <div class="grid gap-3 sm:grid-cols-2">
            <.finance_input form={@household_form} field={:name} label="Household name" placeholder="Garcia Home" />
            <.finance_input form={@household_form} field={:slug} label="Slug optional" placeholder="garcia-home" />
          </div>
          <div class="flex justify-end">
            <button
              type="submit"
              class="btn btn-primary btn-sm inline-flex items-center gap-1"
              aria-label="Create household"
              title="Create household"
            >
              <.icon name="hero-home" class="h-4 w-4" />
              <.icon name="hero-plus" class="h-4 w-4" />
            </button>
          </div>
        </.form>
      </div>

      <div class="rounded-xl border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-5 shadow-sm">
        <div class="flex items-start justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.22em] text-[color:var(--fin-muted)]">Active scope</p>
            <h3 class="mt-2 text-xl font-semibold tracking-tight text-[color:var(--fin-text)]">
              <%= selected_household_name(@selected_household) %>
            </h3>
          </div>
          <span class="rounded-full border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-3 py-1 text-xs font-semibold text-[var(--fin-accent)]">
            <%= household_role_label(@current_scope.user, @selected_household) %>
          </span>
        </div>

        <div class="mt-5 space-y-3">
          <div
            :for={member <- household_member_summaries(@selected_household)}
            class="flex items-center justify-between gap-3 rounded-xl border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-4"
          >
            <div>
              <p class="font-semibold text-[color:var(--fin-text)]"><%= member.name %></p>
              <p class="mt-1 text-xs text-[color:var(--fin-muted)]"><%= member.label %></p>
            </div>
            <span class="rounded-full border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-3 py-1 text-xs font-semibold text-[color:var(--fin-muted)]">
              <%= member.role %>
            </span>
          </div>
          <div :if={@selected_household == nil} class="rounded-xl border border-dashed border-[color:var(--fin-border)] p-4 text-sm text-[color:var(--fin-muted)]">
            Create a household to start shared tracking.
          </div>
        </div>

        <.form
          :if={household_owner?(@current_scope.user, @selected_household)}
          for={@member_form}
          phx-submit="add_household_member"
          class="mt-5 rounded-xl border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-4"
        >
          <div class="grid gap-3 sm:grid-cols-[1fr_auto] sm:items-end">
            <.finance_input form={@member_form} field={:email} label="Add member by email" placeholder="teammate@example.com" />
            <button
              type="submit"
              class="btn btn-secondary btn-sm inline-flex items-center gap-1"
              aria-label="Add member"
              title="Add member"
            >
              <.icon name="hero-user-plus" class="h-4 w-4" />
            </button>
          </div>
        </.form>
      </div>
    </section>
    """
  end

  attr :panel, :string, required: true

  def focus_panel_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6">
      <button
        type="button"
        phx-click="close_focus_panel"
        class="absolute inset-0 bg-[#101828]/40 backdrop-blur-sm"
        aria-label="Close detail panel"
      >
      </button>

      <div class="relative z-10 w-full max-w-5xl overflow-hidden rounded-2xl border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] shadow-2xl">
        <div class="flex items-center justify-between gap-4 border-b border-[color:var(--fin-border)] px-5 py-4 sm:px-6">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.22em] text-[color:var(--fin-muted)]">Detail panel</p>
            <h3 class="mt-2 text-2xl font-semibold tracking-tight text-[color:var(--fin-text)]">
              <%= focus_panel_title(@panel) %>
            </h3>
          </div>
          <button type="button" phx-click="close_focus_panel" class="btn btn-ghost btn-xs">
            <.icon name="hero-x-mark" class="h-4 w-4" />
          </button>
        </div>

        <div class="max-h-[80vh] overflow-y-auto p-5 sm:p-6">
          <.household_panel :if={@panel == "household"} {assigns} />
          <.transaction_panel :if={@panel == "transaction"} {assigns} />
          <.transfer_panel :if={@panel == "transfer"} {assigns} />
          <.account_panel :if={@panel == "account"} {assigns} />
          <.budget_panel :if={@panel == "budget"} {assigns} />
          <.debt_panel :if={@panel == "debt"} {assigns} />
        </div>
      </div>
    </div>
    """
  end

  def accounts_panel(assigns) do
    ~H"""
    <section class="space-y-5">
      <div :if={@accounts != []} class="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        <.account_card :for={account <- @accounts} account={account} />
      </div>

      <div class="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
      <.fin_card>
        <p class="text-xs font-semibold uppercase tracking-[0.24em] text-[color:var(--fin-muted)]">Account setup</p>
        <h2 class="mt-2 text-2xl font-semibold tracking-tight text-[color:var(--fin-text)]">Track balances by scope</h2>

        <.form for={@account_form} phx-submit="create_account" class="mt-5 space-y-4">
          <.account_form_fields form={@account_form} />

          <div class="flex justify-end">
            <button type="submit" class="btn btn-primary btn-sm">Save account</button>
          </div>
        </.form>
      </.fin_card>

      <.fin_card>
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.24em] text-[color:var(--fin-muted)]">Tracked accounts</p>
            <h2 class="mt-2 text-2xl font-semibold tracking-tight text-[color:var(--fin-text)]">Scope balances and activity</h2>
          </div>
          <span class="whitespace-nowrap rounded-full border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-3 py-1 text-xs font-semibold text-[var(--fin-accent)]">
            <%= money_totals(@account_total_balance_totals) %>
          </span>
        </div>

        <div class="mt-5 space-y-3">
          <div :for={summary <- @account_summaries} class="rounded-xl border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-4">
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="font-semibold text-[color:var(--fin-text)]"><%= summary.account.name %></p>
                <p class="mt-1 text-xs text-[color:var(--fin-muted)]"><%= account_summary_subtitle(summary.account) %></p>
              </div>
              <div class="text-right">
                <p class="font-semibold text-[color:var(--fin-text)]"><%= money(summary.account.current_balance, summary.account.currency) %></p>
                <p class="mt-1 text-xs text-[color:var(--fin-muted)]"><%= signed_decimal(summary.net, summary.account.currency) %> this range</p>
              </div>
            </div>

            <div class="mt-3 grid gap-2 text-sm text-[color:var(--fin-muted)] sm:grid-cols-3">
              <.status_row label="Income" value={money(summary.income, summary.account.currency)} />
              <.status_row label="Expenses" value={money(summary.expenses, summary.account.currency)} />
              <.status_row label="Linked tx" value={Integer.to_string(summary.transaction_count)} />
            </div>
          </div>

          <div :if={@account_summaries == []} class="rounded-xl border border-dashed border-[color:var(--fin-border)] p-4 text-sm text-[color:var(--fin-muted)]">
            No accounts yet for this scope.
          </div>
        </div>
      </.fin_card>
      </div>
    </section>
    """
  end

  def transfer_panel(assigns) do
    ~H"""
    <section class="mx-auto max-w-xl">
      <div :if={length(@accounts) < 2} class="rounded-xl border border-dashed border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-5 text-sm text-[color:var(--fin-muted)]">
        You need at least two accounts in this scope to move money between them.
      </div>

      <form :if={length(@accounts) >= 2} phx-submit="create_transfer" class="space-y-4">
        <.transfer_form_fields accounts={@accounts} />

        <p class="text-xs leading-5 text-[color:var(--fin-muted)]">
          Both accounts must use the same currency. Transfers move balances without counting as income or spending.
        </p>

        <div class="flex justify-end">
          <button type="submit" aria-label="Record transfer" class="btn btn-primary btn-sm">
            Transfer
          </button>
        </div>
      </form>
    </section>
    """
  end

  # Shared From/To account selects + amount input for account-to-account
  # transfers. Caller owns the surrounding <form phx-submit="create_transfer">
  # and its own submit/disclaimer content, since the modal and the dashboard's
  # Quick Send card each want different chrome around the same fields.
  attr :accounts, :list, required: true

  defp transfer_form_fields(assigns) do
    ~H"""
    <div class="space-y-3">
      <div class="grid gap-3 sm:grid-cols-2">
        <label class="block">
          <span class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]">From</span>
          <select name="transfer[from_account_id]" class="w-full rounded-lg border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] px-3 py-2.5 text-sm text-[color:var(--fin-text)] outline-none transition focus:border-[var(--fin-accent)] focus:ring-2 focus:ring-[color-mix(in_srgb,var(--fin-accent)_25%,transparent)]">
            <option :for={account <- @accounts} value={account.id}><%= account.name %> (<%= account.currency %>)</option>
          </select>
        </label>
        <label class="block">
          <span class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]">To</span>
          <select name="transfer[to_account_id]" class="w-full rounded-lg border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] px-3 py-2.5 text-sm text-[color:var(--fin-text)] outline-none transition focus:border-[var(--fin-accent)] focus:ring-2 focus:ring-[color-mix(in_srgb,var(--fin-accent)_25%,transparent)]">
            <option :for={account <- transfer_to_options(@accounts)} value={account.id}><%= account.name %> (<%= account.currency %>)</option>
          </select>
        </label>
      </div>

      <label class="block">
        <span class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]">Amount</span>
        <input
          type="number"
          name="transfer[amount]"
          step="0.01"
          min="0.01"
          required
          placeholder="500.00"
          class="w-full rounded-lg border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] px-3 py-2.5 text-sm text-[color:var(--fin-text)] outline-none transition focus:border-[var(--fin-accent)] focus:ring-2 focus:ring-[color-mix(in_srgb,var(--fin-accent)_25%,transparent)]"
        />
      </label>
    </div>
    """
  end

  # Orders the "To" options so the default selection (the first option, since
  # none carry a `selected` attribute) is a same-currency account other than
  # the default "From" (always the first account) — otherwise the untouched
  # defaults are a guaranteed-to-fail cross-currency pair. Falls back to the
  # old "next account in list" order when no same-currency match exists.
  defp transfer_to_options([]), do: []

  defp transfer_to_options([from | rest]) do
    case Enum.split_with(rest, &(&1.currency == from.currency)) do
      {[], others} -> others ++ [from]
      {matches, others} -> matches ++ others ++ [from]
    end
  end

  @doc """
  Quick-add focus panel for a new account, opened from the dashboard's
  "+ Add Card" button — mirrors the "budget"/"debt" quick-add panels so all
  three dashboard "+" actions behave the same way (inline modal, no
  navigation away from the overview).
  """
  def account_panel(assigns) do
    ~H"""
    <section class="mx-auto max-w-xl">
      <.form for={@account_form} phx-submit="create_account" class="space-y-4">
        <.account_form_fields form={@account_form} />

        <div class="flex justify-end">
          <button type="submit" class="btn btn-primary btn-sm">Save account</button>
        </div>
      </.form>
    </section>
    """
  end

  # Shared account fields for both the full Accounts section form and the
  # quick-add focus panel.
  attr :form, :any, required: true

  defp account_form_fields(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="grid gap-3 sm:grid-cols-2">
        <.finance_input form={@form} field={:name} label="Account name" placeholder="Main checking" />
        <.finance_input form={@form} field={:institution} label="Institution" placeholder="Popular Bank" />
        <.finance_select form={@form} field={:kind} label="Kind" options={account_kind_options()} />
        <.finance_select form={@form} field={:currency} label="Currency" options={currency_options()} />
        <.finance_input form={@form} field={:current_balance} label="Current balance" type="number" step="0.01" placeholder="2400.00" />
        <.finance_input form={@form} field={:available_balance} label="Available balance" type="number" step="0.01" placeholder="2200.00" />
      </div>

      <.finance_input form={@form} field={:notes} label="Notes" placeholder="Optional note" />
    </div>
    """
  end

  def transaction_panel(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[0.82fr_1.18fr]">
      <div class="rounded-2xl border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-5 shadow-sm">
        <p class="text-xs font-semibold uppercase tracking-[0.24em] text-[color:var(--fin-muted)]">Manual capture</p>
        <h2 class="mt-2 text-2xl font-semibold tracking-tight text-[color:var(--fin-text)]"><%= transaction_form_title(@editing_transaction_id) %></h2>

        <.form for={@transaction_form} phx-submit={transaction_submit(@editing_transaction_id)} class="mt-5 space-y-4">
          <div class="grid gap-3 sm:grid-cols-2">
            <.finance_select form={@transaction_form} field={:type} label="Type" options={transaction_type_options()} />
            <.finance_input form={@transaction_form} field={:amount} label="Amount" placeholder="125.00" type="number" step="0.01" />
            <.finance_input form={@transaction_form} field={:transaction_date} label="Date" type="date" />
            <.finance_select form={@transaction_form} field={:payment_method} label="Method" options={payment_method_options()} />
            <.finance_select form={@transaction_form} field={:account_id} label="Account" options={account_options(@accounts)} />
          </div>

          <.finance_input form={@transaction_form} field={:description} label="Description" placeholder="Salary, groceries, transfer..." />
          <.finance_select form={@transaction_form} field={:category_id} label="Category" options={category_options(@categories)} />
          <.finance_input form={@transaction_form} field={:notes} label="Notes" placeholder="Optional note" />

          <div class="flex justify-end gap-2">
            <button :if={@editing_transaction_id} type="button" phx-click="cancel_transaction_edit" class="btn btn-ghost btn-sm">
              Cancel
            </button>
            <button type="submit" class="btn btn-primary btn-sm"><%= transaction_submit_label(@editing_transaction_id, @transaction_form[:status].value) %></button>
          </div>
        </.form>
      </div>

      <div class="rounded-2xl border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-5 shadow-sm">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.24em] text-[color:var(--fin-muted)]">Ledger</p>
            <h2 class="mt-2 text-2xl font-semibold tracking-tight text-[color:var(--fin-text)]">Recent transactions</h2>
          </div>
          <span class="text-xs font-semibold text-[color:var(--fin-muted)]"><%= length(@transactions) %> shown</span>
        </div>

        <div class="mt-5 space-y-3">
          <.transaction_row :for={transaction <- Enum.take(@transactions, 6)} transaction={transaction} compact />
          <div :if={@transactions == []} class="rounded-xl border border-dashed border-[color:var(--fin-border)] p-4 text-sm text-[color:var(--fin-muted)]">
            Add income and expenses to start tracking cash flow.
          </div>
        </div>
      </div>
    </section>
    """
  end

  def budget_panel(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[0.82fr_1.18fr]">
      <div class="space-y-5">
        <div class="rounded-2xl border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-5 shadow-sm">
          <p class="text-xs font-semibold uppercase tracking-[0.24em] text-[color:var(--fin-muted)]">Spending plan</p>
          <h2 class="mt-2 text-2xl font-semibold tracking-tight text-[color:var(--fin-text)]">Create budget</h2>

          <.form for={@budget_form} phx-submit="create_budget" class="mt-5 space-y-4">
            <.finance_input form={@budget_form} field={:name} label="Name" placeholder="Groceries, rent, subscriptions..." />
            <div class="grid gap-3 sm:grid-cols-2">
              <.finance_input form={@budget_form} field={:amount} label="Amount" placeholder="400.00" type="number" step="0.01" />
              <.finance_select form={@budget_form} field={:currency} label="Currency" options={currency_options()} />
              <.finance_select form={@budget_form} field={:period} label="Period" options={budget_period_options()} />
              <.finance_input form={@budget_form} field={:start_date} label="Start date" type="date" />
              <.finance_input form={@budget_form} field={:end_date} label="End date" type="date" />
              <.finance_select form={@budget_form} field={:category_id} label="Category" options={category_options(@expense_categories)} />
              <.finance_input form={@budget_form} field={:alert_threshold} label="Alert at %" type="number" step="1" />
            </div>

            <div class="flex justify-end">
              <button type="submit" class="btn btn-primary btn-sm">Save budget</button>
            </div>
          </.form>
        </div>

        <div class="rounded-2xl border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-5 shadow-sm">
          <p class="text-xs font-semibold uppercase tracking-[0.24em] text-[color:var(--fin-muted)]">Categories</p>
          <h2 class="mt-2 text-2xl font-semibold tracking-tight text-[color:var(--fin-text)]">Add category</h2>

          <.form for={@category_form} phx-submit="create_category" class="mt-5 space-y-4">
            <div class="grid gap-3 sm:grid-cols-2">
              <.finance_input form={@category_form} field={:name} label="Name" placeholder="Food, salary..." />
              <.finance_select form={@category_form} field={:type} label="Type" options={transaction_type_options()} />
              <.finance_input form={@category_form} field={:color} label="Color" placeholder="#10B981" />
              <.finance_input form={@category_form} field={:icon} label="Icon" placeholder="wallet" />
            </div>
            <.finance_input form={@category_form} field={:description} label="Description" placeholder="Optional description" />

            <div class="flex justify-end">
              <button type="submit" class="btn btn-secondary btn-sm">Save category</button>
            </div>
          </.form>
        </div>
      </div>

      <div class="rounded-2xl border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-5 shadow-sm">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.24em] text-[color:var(--fin-muted)]">Active budgets</p>
            <h2 class="mt-2 text-2xl font-semibold tracking-tight text-[color:var(--fin-text)]">Budget status</h2>
          </div>
          <span class="text-xs font-semibold text-[color:var(--fin-muted)]"><%= money_totals(@budget_remaining_totals) %> remaining</span>
        </div>

        <div class="mt-5 space-y-3">
          <.budget_status_card :for={status <- @budget_statuses} status={status} />
          <div :if={@budget_statuses == []} class="rounded-xl border border-dashed border-[color:var(--fin-border)] p-4 text-sm text-[color:var(--fin-muted)]">
            No active budgets yet.
          </div>
        </div>
      </div>
    </section>
    """
  end

  def debt_panel(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
      <div class="rounded-2xl border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-5 shadow-sm">
        <div>
          <p class="text-xs font-semibold uppercase tracking-[0.24em] text-[color:var(--fin-muted)]">Debt setup</p>
          <h2 class="mt-2 text-2xl font-semibold tracking-tight text-[color:var(--fin-text)]">Add debt</h2>
        </div>

        <.form for={@debt_form} phx-submit="create_debt" class="mt-5 rounded-xl border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-4">
          <div class="grid gap-3 md:grid-cols-2">
            <.finance_input form={@debt_form} field={:name} label="Name" placeholder="Visa, auto loan..." />
            <.finance_input form={@debt_form} field={:provider} label="Provider" placeholder="Bank or lender" />
            <.finance_select form={@debt_form} field={:kind} label="Kind" options={debt_kind_options()} />
            <.finance_select form={@debt_form} field={:currency} label="Currency" options={currency_options()} />
            <.finance_input form={@debt_form} field={:current_balance} label="Current balance" placeholder="2500.00" type="number" step="0.01" />
            <.finance_input form={@debt_form} field={:minimum_payment} label="Minimum payment" placeholder="75.00" type="number" step="0.01" />
            <.finance_input form={@debt_form} field={:apr} label="APR optional" placeholder="24.99" type="number" step="0.0001" />
            <.finance_input form={@debt_form} field={:due_day} label="Due day" placeholder="15" type="number" step="1" />
            <.finance_input form={@debt_form} field={:payoff_goal_date} label="Goal date" type="date" />
          </div>

          <div class="mt-4 flex justify-end">
            <button type="submit" class="btn btn-primary btn-sm">Save debt</button>
          </div>
        </.form>

        <div class="mt-5 space-y-3">
          <div :if={@debts == []} class="rounded-xl border border-dashed border-[color:var(--fin-border)] p-4 text-sm text-[color:var(--fin-muted)]">
            Add debts to compare payoff strategies.
          </div>

          <.debt_card :for={debt <- @debts} debt={debt} payment_form={@payment_form} payment_form_debt_id={@payment_form_debt_id} />
        </div>
      </div>

      <div class="rounded-2xl border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-5 shadow-sm">
        <div class="flex flex-wrap items-center justify-between gap-4">
              <div>
                <p class="text-xs font-semibold uppercase tracking-[0.24em] text-[color:var(--fin-muted)]">Payoff comparison</p>
                <h2 class="mt-2 text-2xl font-semibold tracking-tight text-[color:var(--fin-text)]">Snowball vs avalanche</h2>
              </div>
          <button type="button" phx-click="generate_plans" class="btn btn-primary btn-xs">Refresh</button>
        </div>

        <div class="mt-5 grid gap-4 lg:grid-cols-2">
          <.plan_card :for={plan <- @comparison} plan={plan} debt_currencies={@debt_currencies} />
          <div :if={@comparison == []} class="rounded-lg border border-dashed border-[color:var(--fin-border)] p-4 text-sm text-[color:var(--fin-muted)] lg:col-span-2">
            Generate plans to compare payoff order, payoff month, and estimated interest.
          </div>
        </div>
      </div>
    </section>
    """
  end

  def goal_panel(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[0.82fr_1.18fr]">
      <div class="rounded-2xl border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] p-5 shadow-sm">
        <p class="text-xs font-semibold uppercase tracking-[0.24em] text-[color:var(--fin-muted)]">Savings goals</p>
        <h2 class="mt-2 text-2xl font-semibold tracking-tight text-[color:var(--fin-text)]">Create goal</h2>

        <.form for={@goal_form} phx-submit="create_goal" class="mt-5 space-y-4">
          <.finance_input form={@goal_form} field={:name} label="Goal name" placeholder="Emergency fund, vacation..." />
          <div class="grid gap-3 sm:grid-cols-2">
            <.finance_input form={@goal_form} field={:target_amount} label="Target amount" type="number" step="0.01" placeholder="5000.00" />
            <.finance_select form={@goal_form} field={:currency} label="Currency" options={currency_options()} />
            <.finance_input form={@goal_form} field={:saved_amount} label="Already saved" type="number" step="0.01" placeholder="0.00" />
            <.finance_input form={@goal_form} field={:target_date} label="Target date" type="date" />
          </div>
          <.finance_input form={@goal_form} field={:notes} label="Notes" placeholder="Optional note" />

          <div class="flex justify-end">
            <button type="submit" class="btn btn-primary btn-sm">Save goal</button>
          </div>
        </.form>
      </div>

      <div class="rounded-2xl border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] p-5 shadow-sm">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.24em] text-[color:var(--fin-muted)]">Progress</p>
            <h2 class="mt-2 text-2xl font-semibold tracking-tight text-[color:var(--fin-text)]">Active goals</h2>
          </div>
          <span class="rounded-full border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-3 py-1 text-xs font-semibold text-[var(--fin-accent)]">
            <%= length(@savings_goals) %> tracked
          </span>
        </div>

        <div class="mt-5 space-y-3">
          <.savings_goal_card :for={goal <- @savings_goals} goal={goal} />
          <div :if={@savings_goals == []} class="rounded-xl border border-dashed border-[color:var(--fin-border)] p-4 text-sm text-[color:var(--fin-muted)]">
            Create your first savings goal to start tracking progress.
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :goal, :any, required: true

  def savings_goal_card(assigns) do
    assigns = assign(assigns, :pct, savings_goal_percentage(assigns.goal))

    ~H"""
    <div class="rounded-lg border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-4">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p class="font-semibold text-[color:var(--fin-text)]"><%= @goal.name %></p>
          <p class="mt-1 text-xs text-[color:var(--fin-muted)]">
            <%= if @goal.target_date, do: "Target #{format_date(@goal.target_date)}", else: "No target date" %>
          </p>
        </div>
        <span class={["rounded-full px-2.5 py-1 text-xs font-semibold", tone_class(savings_goal_tone(@goal), :soft)]}>
          <%= savings_goal_state_label(@goal) %>
        </span>
      </div>

      <div class="mt-4 h-2 overflow-hidden rounded-full bg-[color:var(--fin-surface)]">
        <div class={["h-full rounded-full", tone_class(savings_goal_tone(@goal), :bar)]} style={"width: #{min(@pct, 100)}%"} />
      </div>

      <div class="mt-3 grid grid-cols-3 gap-2 text-xs">
        <div>
          <p class="text-[color:var(--fin-muted)]">Saved</p>
          <p class="mt-1 font-semibold text-[color:var(--fin-text)]"><%= money(@goal.saved_amount, @goal.currency) %></p>
        </div>
        <div>
          <p class="text-[color:var(--fin-muted)]">Target</p>
          <p class="mt-1 font-semibold text-[color:var(--fin-text)]"><%= money(@goal.target_amount, @goal.currency) %></p>
        </div>
        <div>
          <p class="text-[color:var(--fin-muted)]">Progress</p>
          <p class="mt-1 font-semibold text-[color:var(--fin-text)]"><%= Float.round(@pct, 1) %>%</p>
        </div>
      </div>

      <div class="mt-4 flex justify-end">
        <button type="button" phx-click="archive_goal" phx-value-id={@goal.id} class="btn btn-ghost btn-xs text-[var(--tone-expense)]">
          Archive
        </button>
      </div>
    </div>
    """
  end

  attr :goal, :any, required: true

  def savings_goal_mini_row(assigns) do
    assigns = assign(assigns, :pct, savings_goal_percentage(assigns.goal))

    ~H"""
    <div>
      <div class="flex items-center justify-between gap-4 text-sm">
        <span class="truncate font-medium text-[color:var(--fin-text)]"><%= @goal.name %></span>
        <span class="font-mono text-[12px] text-[color:var(--fin-muted)]"><%= @pct |> min(100) |> trunc() %>%</span>
      </div>
      <div class="mt-2.5 h-1.5 overflow-hidden rounded-full bg-[color:var(--fin-surface)]">
        <div class={["h-full rounded-full", tone_class(savings_goal_tone(@goal), :bar)]} style={"width: #{min(@pct, 100)}%"} />
      </div>
    </div>
    """
  end

  def overview_section(assigns) do
    ~H"""
    <section class="space-y-5">
      <div class="relative overflow-hidden rounded-[2rem] border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-3 shadow-[0_24px_48px_-32px_var(--fin-glass-shadow)] sm:p-4">
        <div class="pointer-events-none absolute inset-0 bg-[radial-gradient(60%_60%_at_15%_0%,color-mix(in_srgb,var(--fin-accent)_10%,transparent),transparent)]"></div>
        <div class="relative grid gap-5 xl:grid-cols-12">
          <div class="xl:col-span-6">
            <.balance_hero_card hero={@hero} />
          </div>

          <div class="grid gap-5 sm:grid-cols-2 xl:col-span-6">
            <.stat_tile
              label="Total Balance"
              value={money(@hero.balance, @hero.currency)}
              icon="hero-banknotes"
              tone="budget"
              delta={@hero.balance_delta}
            />
            <.stat_tile
              label="Monthly Income"
              value={money(@hero.income, @hero.currency)}
              icon="hero-arrow-trending-up"
              tone="income"
              delta={@hero.income_delta}
            />
            <.stat_tile
              label="Total Spent"
              value={money(@hero.spent, @hero.currency)}
              icon="hero-arrow-trending-down"
              tone="expense"
              delta={@hero.spent_delta}
            />
            <.stat_tile
              label="Saving Rate"
              value={hero_rate_value(@hero.saving_rate)}
              icon="hero-shield-check"
              tone="debt"
              show_delta={false}
            >
              <.saving_rate_radial rate={@hero.saving_rate} goal={@hero.saving_goal} />
            </.stat_tile>
          </div>
        </div>
      </div>

      <div class="grid gap-5 xl:grid-cols-3">
        <.budget_mini_card
          budget_statuses={@budget_statuses}
          budget_spent_totals={@budget_spent_totals}
          budget_remaining_totals={@budget_remaining_totals}
          budget_usage_pct={@budget_usage_pct}
        />

        <.fin_card>
          <div class="flex items-center justify-between gap-3">
            <div>
              <p class="text-[11px] font-semibold uppercase tracking-[0.22em] text-[color:var(--fin-muted)]">Review</p>
              <h2 class="mt-2 text-lg font-semibold text-[color:var(--fin-text)]">Pending queue</h2>
            </div>
            <button type="button" phx-click="show_section" phx-value-section="review" class="text-[11px] font-semibold uppercase tracking-[0.16em] text-[color:var(--fin-muted)] transition hover:text-[color:var(--fin-text)]">
              Open review queue
            </button>
          </div>

          <div class="mt-5 space-y-2.5">
            <div :for={transaction <- Enum.take(@pending_transactions, 3)} class="rounded-[1.05rem] border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-3.5">
              <div class="flex items-start justify-between gap-3">
                <div class="min-w-0">
                  <p class="truncate font-medium text-[color:var(--fin-text)]"><%= review_title(transaction) %></p>
                  <p class="mt-1 text-xs text-[color:var(--fin-muted)]"><%= format_date(transaction.transaction_date) %></p>
                </div>
                <span class="rounded-full bg-[color-mix(in_srgb,var(--tone-review)_16%,transparent)] px-2 py-1 text-[11px] font-semibold text-[var(--tone-review)]">Review</span>
              </div>
            </div>

            <div :if={@pending_transactions == []} class="rounded-[1rem] border border-dashed border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-4 py-4 text-sm text-[color:var(--fin-muted)]">
              Queue clear.
            </div>
          </div>
        </.fin_card>

        <.fin_card>
          <div class="flex items-center justify-between gap-3">
            <div>
              <p class="text-[11px] font-semibold uppercase tracking-[0.22em] text-[color:var(--fin-muted)]">Obligations</p>
              <h2 class="mt-2 text-lg font-semibold text-[color:var(--fin-text)]">Debts</h2>
            </div>
            <div class="flex items-center gap-3">
              <button
                type="button"
                phx-click="open_focus_panel"
                phx-value-panel="debt"
                aria-label="Add debt"
                title="Add debt"
                class="text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--fin-accent)] transition hover:text-[color:var(--fin-text)]"
              >
                + Debt
              </button>
              <button type="button" phx-click="show_section" phx-value-section="debts" class="text-[11px] font-semibold uppercase tracking-[0.16em] text-[color:var(--fin-muted)] transition hover:text-[color:var(--fin-text)]">
                Details
              </button>
            </div>
          </div>

          <div class="mt-5 space-y-2.5">
            <div :for={debt <- Enum.take(@debts, 3)} class="rounded-[1.05rem] border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-4 py-3.5">
              <div class="flex items-start justify-between gap-4">
                <div>
                  <p class="font-medium text-[color:var(--fin-text)]"><%= debt.name %></p>
                  <p class="mt-1 text-xs text-[color:var(--fin-muted)]"><%= due_day_label(debt.due_day) %></p>
                </div>
                <div class="text-right">
                  <p class="font-mono text-sm font-semibold text-[color:var(--fin-text)]"><%= money(debt.current_balance, debt.currency) %></p>
                  <p class="mt-1 text-xs text-[color:var(--fin-muted)]"><%= money(debt.minimum_payment, debt.currency) %> min</p>
                </div>
              </div>
            </div>

            <div :if={@debts == []} class="rounded-[1rem] border border-dashed border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-4 py-4 text-sm text-[color:var(--fin-muted)]">
              No debts tracked.
            </div>
          </div>
        </.fin_card>
      </div>

      <div class="grid gap-5 xl:grid-cols-12">
        <.fin_card class="xl:col-span-8">
          <div class="flex flex-wrap items-start justify-between gap-4">
            <h2 class="text-lg font-semibold tracking-tight text-[color:var(--fin-text)]">Cashflow Overview</h2>
            <div class="flex items-center gap-1.5">
              <form phx-change="select_cashflow_year">
                <select
                  name="year"
                  class="rounded-lg border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] px-2 py-1 text-[11px] font-semibold text-[color:var(--fin-text)] outline-none transition focus:border-[var(--fin-accent)]"
                >
                  <option :for={year <- @cashflow.year_options} value={year} selected={year == @cashflow_year}>
                    <%= year %>
                  </option>
                </select>
              </form>
              <form phx-change="select_cashflow_window">
                <select
                  name="window"
                  class="rounded-lg border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] px-2 py-1 text-[11px] font-semibold text-[color:var(--fin-text)] outline-none transition focus:border-[var(--fin-accent)]"
                >
                  <option :for={window <- [3, 6, 12]} value={window} selected={window == @cashflow_window}>
                    <%= window %> Month
                  </option>
                </select>
              </form>
            </div>
          </div>

          <div class="mt-4 flex flex-wrap items-center gap-3">
            <div>
              <p class="text-xs font-medium text-[color:var(--fin-muted)]">Total Revenue</p>
              <p class="mt-1 font-mono text-[1.45rem] font-semibold leading-none tracking-[-0.03em] text-[color:var(--fin-text)]">
                <%= money(@cashflow.revenue, @cashflow.currency) %>
              </p>
            </div>
            <span
              :if={@cashflow.revenue_delta}
              class={[
                "inline-flex items-center gap-0.5 rounded-full px-2 py-0.5 text-xs font-semibold",
                @cashflow.revenue_delta >= 0 && tone_class("income", :soft),
                @cashflow.revenue_delta < 0 && tone_class("expense", :soft)
              ]}
            >
              <%= if @cashflow.revenue_delta >= 0, do: "+", else: "" %><%= Float.round(@cashflow.revenue_delta / 1, 2) %>%
            </span>
          </div>

          <.cashflow_chart id="overview-cashflow" cashflow_months={@cashflow_months} class="mt-2" />
        </.fin_card>

        <.fin_card class="xl:col-span-4">
          <div class="flex flex-wrap items-center justify-between gap-4">
            <div>
              <h2 class="text-lg font-semibold tracking-tight text-[color:var(--fin-text)]">My Cards</h2>
              <p class="mt-1 text-sm text-[color:var(--fin-muted)]"><%= money_totals(@account_total_balance_totals) %></p>
            </div>
            <button
              type="button"
              phx-click="open_focus_panel"
              phx-value-panel="account"
              aria-label="Add account"
              title="Add account"
              class="rounded-lg border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] px-3 py-1.5 text-xs font-semibold text-[color:var(--fin-text)] transition hover:bg-[color:var(--fin-surface)]"
            >
              + Add Card
            </button>
          </div>

          <div class="mt-5 space-y-3.5">
            <.account_card :for={account <- Enum.take(@accounts, 2)} account={account} />

            <div :if={@accounts == []} class="rounded-xl border border-dashed border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-4 py-8 text-center text-sm text-[color:var(--fin-muted)]">
              No accounts yet. Add one from the Accounts section.
            </div>

            <button
              :if={length(@accounts) > 2}
              type="button"
              phx-click="show_section"
              phx-value-section="accounts"
              class="w-full rounded-xl border border-dashed border-[color:var(--fin-border)] px-4 py-2.5 text-sm font-semibold text-[color:var(--fin-muted)] transition hover:bg-[color:var(--fin-surface)] hover:text-[color:var(--fin-text)]"
            >
              View all <%= length(@accounts) %> accounts
            </button>
          </div>
        </.fin_card>
      </div>

      <div class="grid gap-5 xl:grid-cols-12">
        <.fin_card class="xl:col-span-8">
          <div class="flex flex-wrap items-center justify-between gap-4">
            <div>
              <p class="text-[11px] font-semibold uppercase tracking-[0.22em] text-[color:var(--fin-muted)]">Spending</p>
              <h2 class="mt-1 text-lg font-semibold tracking-tight text-[color:var(--fin-text)]">By category · this month</h2>
            </div>
            <button type="button" phx-click="show_section" phx-value-section="budgets" class="text-[11px] font-semibold uppercase tracking-[0.16em] text-[color:var(--fin-muted)] transition hover:text-[color:var(--fin-text)]">
              Open budgets
            </button>
          </div>

          <.spending_donut :if={@spending_breakdown != []} id="overview-spending" breakdown={@spending_breakdown} class="mt-4" />
          <div :if={@spending_breakdown == []} class="mt-5 rounded-xl border border-dashed border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-4 py-8 text-center text-sm text-[color:var(--fin-muted)]">
            No spending recorded this month.
          </div>
        </.fin_card>

        <.fin_card class="xl:col-span-4">
          <div>
            <p class="text-[11px] font-semibold uppercase tracking-[0.22em] text-[color:var(--fin-muted)]">Payment & transfer</p>
            <h2 class="mt-1 text-lg font-semibold tracking-tight text-[color:var(--fin-text)]">Quick Send</h2>
          </div>

          <div :if={length(@accounts) < 2} class="mt-4 rounded-xl border border-dashed border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-4 py-6 text-center text-sm text-[color:var(--fin-muted)]">
            Add a second account to send money between your own accounts.
          </div>

          <form :if={length(@accounts) >= 2} phx-submit="create_transfer" class="mt-4 space-y-3">
            <.transfer_form_fields accounts={@accounts} />
            <p class="text-xs leading-5 text-[color:var(--fin-muted)]">
              Both accounts must use the same currency.
            </p>
            <button type="submit" aria-label="Send transfer" class="btn btn-primary btn-sm w-full">
              Send
            </button>
          </form>
        </.fin_card>
      </div>

      <div class="grid gap-5">
        <.fin_card>
          <div class="flex items-center justify-between gap-4">
            <div>
              <p class="text-[11px] font-semibold uppercase tracking-[0.22em] text-[color:var(--fin-muted)]">Activity</p>
              <h2 class="mt-2 text-xl font-semibold tracking-tight text-[color:var(--fin-text)]">Recent transactions</h2>
            </div>
            <button type="button" phx-click="show_section" phx-value-section="transactions" class="text-[11px] font-semibold uppercase tracking-[0.16em] text-[color:var(--fin-muted)] transition hover:text-[color:var(--fin-text)]">
              View all
            </button>
          </div>

          <div class="mt-5 space-y-2.5">
            <div :for={transaction <- @recent_transactions} class="flex items-center gap-3 rounded-[1.12rem] border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-4 py-3.5">
              <span class={["inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-xl", tone_class(transaction.type, :soft)]}>
                <.icon
                  name={if transaction.type == "income", do: "hero-arrow-trending-up", else: "hero-arrow-trending-down"}
                  class="h-4 w-4"
                />
              </span>
              <div class="min-w-0 flex-1">
                <p class="truncate font-medium text-[color:var(--fin-text)]"><%= transaction.description || review_title(transaction) %></p>
                <div class="mt-1 flex flex-wrap items-center gap-2 text-[11px] text-[color:var(--fin-muted)]">
                  <span><%= format_date(transaction.transaction_date) %></span>
                  <span :if={transaction.account} class="rounded-full bg-[color:var(--fin-surface)] px-2 py-1"><%= transaction.account.name %></span>
                  <.fin_badge :if={transaction.counterpart_transaction_id} tone="muted">Transfer</.fin_badge>
                </div>
              </div>
              <p class={["shrink-0 pt-0.5 font-mono text-sm font-semibold", tone_class(transaction.type)]}>
                <%= signed_money(transaction) %>
              </p>
            </div>

            <div :if={@recent_transactions == []} class="rounded-[1.1rem] border border-dashed border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-4 py-5 text-sm text-[color:var(--fin-muted)]">
              No transactions yet.
            </div>
          </div>
        </.fin_card>
      </div>
    </section>
    """
  end

  def networth_section(assigns) do
    assigns =
      assigns
      |> assign(
        :visible_net_worth_items,
        net_worth_visible_items(assigns.net_worth_items, assigns.net_worth_filter)
      )
      |> assign(:net_worth_max_amount, net_worth_max_amount(assigns.net_worth_items))
      |> assign(:net_worth_donut, net_worth_donut_breakdown(assigns.net_worth_allocation))

    ~H"""
    <section>
      <.fin_card padded={false} class="p-6 sm:p-7 xl:p-8">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p class="text-[11px] font-semibold uppercase tracking-[0.24em] text-[color:var(--fin-muted)]">Overview</p>
            <h2 class="mt-2 text-[1.65rem] font-semibold tracking-tight text-[color:var(--fin-text)]">Net worth</h2>
            <p class="mt-1 max-w-xl text-sm leading-6 text-[color:var(--fin-muted)]">
              Everything you own minus everything you owe, pulled live from your tracked accounts and debts.
            </p>
          </div>
          <span class="rounded-full border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-3 py-1.5 text-xs font-medium text-[color:var(--fin-muted)]">
            <%= length(@net_worth_items) %> tracked items
          </span>
        </div>

        <div class="mt-6 grid gap-4 sm:grid-cols-3">
          <.stat_tile label="Net worth" value={@net_worth_summary.net} icon="hero-banknotes" tone="budget" show_delta={false} />
          <.stat_tile label="Assets" value={@net_worth_summary.assets} icon="hero-arrow-trending-up" tone="income" show_delta={false} />
          <.stat_tile label="Liabilities" value={@net_worth_summary.liabilities} icon="hero-arrow-trending-down" tone="expense" show_delta={false} />
        </div>

        <div :if={@net_worth_donut != []} class="mt-6 rounded-[1.55rem] border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-5">
          <p class="text-[11px] font-semibold uppercase tracking-[0.16em] text-[color:var(--fin-muted)]">
            <%= net_worth_donut_currency(@net_worth_allocation) %> composition
          </p>
          <.spending_donut id="networth-donut" breakdown={@net_worth_donut} class="mt-2" />
        </div>

        <div class="mt-7 flex flex-wrap items-center justify-between gap-3">
          <h3 class="text-sm font-semibold text-[color:var(--fin-text)]">Accounts &amp; debts</h3>
          <div class="flex flex-wrap gap-1.5">
            <.net_worth_filter_pill category="all" label="All" active={@net_worth_filter == "all"} />
            <.net_worth_filter_pill
              :for={group <- @net_worth_groups}
              category={group.key}
              label={group.label}
              active={@net_worth_filter == group.key}
            />
          </div>
        </div>

        <div class="mt-3 divide-y divide-[color:var(--fin-border)]">
          <.net_worth_row
            :for={item <- @visible_net_worth_items}
            item={item}
            meta={networth_category_meta(item.category)}
            max_amount={@net_worth_max_amount}
          />
          <div :if={@visible_net_worth_items == []} class="rounded-xl border border-dashed border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-4 text-sm text-[color:var(--fin-muted)]">
            <%= if @net_worth_items == [],
              do: "Add an account or a debt to see your net worth here.",
              else: "No items in this category yet." %>
          </div>
        </div>
      </.fin_card>
    </section>
    """
  end

  attr :category, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false

  def net_worth_filter_pill(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="filter_net_worth"
      phx-value-category={@category}
      class={[
        "rounded-full border px-3 py-1.5 text-xs font-semibold transition",
        @active && "border-[#465fff] bg-[#465fff] text-white shadow-sm",
        !@active && "border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] text-[color:var(--fin-muted)] hover:bg-[color:var(--fin-surface)] hover:text-[color:var(--fin-text)]"
      ]}
    >
      <%= @label %>
    </button>
    """
  end

  attr :item, :map, required: true
  attr :meta, :map, required: true
  attr :max_amount, :float, required: true

  def net_worth_row(assigns) do
    ~H"""
    <div class="flex items-center gap-4 py-3.5">
      <div class={["flex h-10 w-10 shrink-0 items-center justify-center rounded-xl", tone_class(@meta.tone, :soft)]}>
        <.icon name={@meta.icon} class="h-[18px] w-[18px]" />
      </div>
      <div class="min-w-0 flex-1">
        <p class="truncate text-sm font-medium text-[color:var(--fin-text)]"><%= @item.name %></p>
        <p class="text-xs text-[color:var(--fin-muted)]"><%= @item.subtitle %> · <%= @meta.label %></p>
      </div>
      <div class="hidden w-28 md:block">
        <div class="h-1.5 w-full overflow-hidden rounded-full bg-[color:var(--fin-surface)]">
          <div
            class={["h-full rounded-full", tone_class(@meta.tone, :bar)]}
            style={"width: #{min(100, round(abs(decimal_to_float(@item.amount)) / @max_amount * 100))}%"}
          >
          </div>
        </div>
      </div>
      <p class={[
        "w-32 shrink-0 text-right font-mono text-sm tabular-nums",
        Decimal.compare(@item.amount, Decimal.new("0")) == :lt && "text-[var(--tone-expense)]",
        Decimal.compare(@item.amount, Decimal.new("0")) != :lt && "text-[color:var(--fin-text)]"
      ]}>
        <%= money(@item.amount, @item.currency) %>
      </p>
    </div>
    """
  end

  def transactions_section(assigns) do
    ~H"""
    <section class="space-y-5">
      <.fin_card>
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]">Ledger · <%= @date_window_label %></p>
            <h2 class="mt-1 text-xl font-semibold text-[color:var(--fin-text)]">Transactions</h2>
          </div>
          <div class="flex flex-wrap items-center gap-2.5">
            <div class="inline-flex flex-wrap items-center gap-1 rounded-full border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-1.5 py-1.5">
              <.time_scope_button current={@time_scope} scope="day" bubble />
              <.time_scope_button current={@time_scope} scope="week" bubble />
              <.time_scope_button current={@time_scope} scope="month" bubble />
              <.time_scope_button current={@time_scope} scope="year" bubble />
            </div>
            <button type="button" phx-click="open_focus_panel" phx-value-panel="transaction" class="btn btn-primary btn-sm">
              + Add transaction
            </button>
          </div>
        </div>

        <form phx-change="filter_transactions" class="mt-5 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
          <.txn_filter_select name="filters[type]" label="Type" value={@txn_filters["type"]} options={[{"All types", ""}, {"Income", "income"}, {"Expense", "expense"}]} />
          <.txn_filter_select name="filters[status]" label="Status" value={@txn_filters["status"]} options={[{"Confirmed + pending", ""}, {"Confirmed", "confirmed"}, {"Pending review", "pending_review"}, {"Ignored", "ignored"}]} />
          <.txn_filter_select name="filters[category_id]" label="Category" value={@txn_filters["category_id"]} options={[{"All categories", ""} | Enum.map(@categories, &{&1.name, &1.id})]} />
          <.txn_filter_select name="filters[account_id]" label="Account" value={@txn_filters["account_id"]} options={[{"All accounts", ""} | Enum.map(@accounts, &{&1.name, &1.id})]} />
        </form>

        <div class="mt-5 overflow-x-auto">
          <table class="w-full min-w-[44rem] text-left text-sm">
            <thead>
              <tr class="border-b border-[color:var(--fin-border)]">
                <.txn_sort_th field="transaction_date" label="Date" sort={@txn_sort} />
                <th class="px-3 py-3 text-[11px] font-semibold uppercase tracking-[0.14em] text-[color:var(--fin-muted)]">Description</th>
                <th class="hidden px-3 py-3 text-[11px] font-semibold uppercase tracking-[0.14em] text-[color:var(--fin-muted)] lg:table-cell">Category</th>
                <th class="hidden px-3 py-3 text-[11px] font-semibold uppercase tracking-[0.14em] text-[color:var(--fin-muted)] lg:table-cell">Account</th>
                <th class="px-3 py-3 text-[11px] font-semibold uppercase tracking-[0.14em] text-[color:var(--fin-muted)]">Status</th>
                <.txn_sort_th field="amount" label="Amount" sort={@txn_sort} class="text-right" />
                <th class="px-3 py-3"></th>
              </tr>
            </thead>
            <tbody class="divide-y divide-[color:var(--fin-border)]">
              <tr :for={transaction <- @txn_rows} class="transition hover:bg-[color:var(--fin-surface)]">
                <td class="whitespace-nowrap px-3 py-3.5 text-[color:var(--fin-muted)]"><%= format_date(transaction.transaction_date) %></td>
                <td class="max-w-[16rem] px-3 py-3.5">
                  <p class="truncate font-medium text-[color:var(--fin-text)]"><%= transaction.description || review_title(transaction) %></p>
                  <p :if={transaction.merchant} class="mt-0.5 truncate text-xs text-[color:var(--fin-muted)]"><%= transaction.merchant %></p>
                </td>
                <td class="hidden px-3 py-3.5 text-[color:var(--fin-muted)] lg:table-cell"><%= category_name(transaction.category) %></td>
                <td class="hidden px-3 py-3.5 text-[color:var(--fin-muted)] lg:table-cell"><%= (transaction.account && transaction.account.name) || "—" %></td>
                <td class="px-3 py-3.5">
                  <.fin_badge :if={transaction.counterpart_transaction_id} tone="muted">Transfer</.fin_badge>
                  <.fin_badge :if={!transaction.counterpart_transaction_id} tone={transaction_status_tone(transaction.status)}>
                    <%= transaction_status_label(transaction.status) %>
                  </.fin_badge>
                </td>
                <td class={["whitespace-nowrap px-3 py-3.5 text-right font-mono font-semibold", tone_class(transaction.type)]}>
                  <%= signed_money(transaction) %>
                </td>
                <td class="whitespace-nowrap px-3 py-3.5 text-right">
                  <button type="button" phx-click="open_edit_transaction" phx-value-id={transaction.id} class="btn btn-secondary btn-xs">
                    Edit
                  </button>
                  <button type="button" phx-click="delete_transaction" phx-value-id={transaction.id} class="btn btn-ghost btn-xs text-[var(--tone-expense)]">
                    Delete
                  </button>
                </td>
              </tr>
            </tbody>
          </table>

          <div :if={@txn_rows == []} class="rounded-xl border border-dashed border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-6 text-center text-sm text-[color:var(--fin-muted)]">
            No transactions match these filters.
          </div>
        </div>

        <div class="mt-5 flex flex-wrap items-center justify-between gap-3 border-t border-[color:var(--fin-border)] pt-4">
          <p class="text-xs text-[color:var(--fin-muted)]">
            <%= @txn_total %> transactions · page <%= @txn_page %> of <%= @txn_pages %>
          </p>
          <div class="flex items-center gap-2">
            <button
              type="button"
              phx-click="paginate_transactions"
              phx-value-page={@txn_page - 1}
              disabled={@txn_page <= 1}
              class="btn btn-secondary btn-xs disabled:cursor-not-allowed disabled:opacity-40"
            >
              Previous
            </button>
            <button
              type="button"
              phx-click="paginate_transactions"
              phx-value-page={@txn_page + 1}
              disabled={@txn_page >= @txn_pages}
              class="btn btn-secondary btn-xs disabled:cursor-not-allowed disabled:opacity-40"
            >
              Next
            </button>
          </div>
        </div>
      </.fin_card>
    </section>
    """
  end

  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, default: nil
  attr :options, :list, required: true

  defp txn_filter_select(assigns) do
    ~H"""
    <label class="block">
      <span class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]"><%= @label %></span>
      <select
        name={@name}
        class="w-full rounded-lg border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] px-3 py-2 text-sm text-[color:var(--fin-text)] outline-none transition focus:border-[var(--fin-accent)] focus:ring-2 focus:ring-[color-mix(in_srgb,var(--fin-accent)_25%,transparent)]"
      >
        <option :for={{label, value} <- @options} value={value} selected={to_string(@value) == to_string(value)}>
          <%= label %>
        </option>
      </select>
    </label>
    """
  end

  attr :field, :string, required: true
  attr :label, :string, required: true
  attr :sort, :any, required: true
  attr :class, :any, default: nil

  defp txn_sort_th(assigns) do
    {sort_field, sort_direction} = assigns.sort
    active? = to_string(sort_field) == assigns.field

    assigns = assign(assigns, active?: active?, direction: sort_direction)

    ~H"""
    <th class={["px-3 py-3", @class]}>
      <button
        type="button"
        phx-click="sort_transactions"
        phx-value-field={@field}
        class={[
          "inline-flex items-center gap-1 text-[11px] font-semibold uppercase tracking-[0.14em] transition",
          @active? && "text-[var(--fin-accent)]",
          !@active? && "text-[color:var(--fin-muted)] hover:text-[color:var(--fin-text)]"
        ]}
      >
        <%= @label %>
        <span :if={@active?}><%= if @direction == :desc, do: "▼", else: "▲" %></span>
      </button>
    </th>
    """
  end

  def review_section(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[1.1fr_0.9fr]">
      <div class="rounded-2xl border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] p-5 shadow-[0_16px_32px_-24px_var(--fin-glass-shadow)] sm:p-6">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]">Pending review</p>
            <h2 class="mt-1 text-xl font-semibold text-[color:var(--fin-text)]">Imported transaction suggestions</h2>
          </div>
          <span class="text-xs font-semibold text-[color:var(--fin-muted)]"><%= @pending_review_count %> waiting</span>
        </div>

        <div class="mt-4 space-y-3">
          <.review_row :for={transaction <- @pending_transactions} transaction={transaction} />
          <div :if={@pending_transactions == []} class="rounded-xl border border-dashed border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-4 text-sm text-[color:var(--fin-muted)]">
            No pending items right now.
          </div>
        </div>
      </div>

      <div class="rounded-2xl border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] p-5 shadow-[0_16px_32px_-24px_var(--fin-glass-shadow)] sm:p-6">
        <p class="text-xs font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]">Review cadence</p>
        <h2 class="mt-1 text-xl font-semibold text-[color:var(--fin-text)]">What happens here</h2>
        <div class="mt-5 space-y-3 text-sm leading-6 text-[color:var(--fin-muted)]">
          <p>Imported candidates wait here before they affect balances and budgets.</p>
          <p>Confirm keeps the item in the ledger. Ignore removes the suggestion.</p>
          <p>Edit lets you correct the details before confirming.</p>
        </div>
      </div>
    </section>
    """
  end

  def budgets_section(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[0.72fr_1.28fr]">
      <div class="rounded-2xl border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] p-5 shadow-[0_16px_32px_-24px_var(--fin-glass-shadow)] sm:p-6">
        <p class="text-xs font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]">Planning</p>
        <h2 class="mt-1 text-xl font-semibold text-[color:var(--fin-text)]">Budgets</h2>
        <div class="mt-5">
          <button
            type="button"
            phx-click="open_focus_panel"
            phx-value-panel="budget"
            aria-label="Create budget"
            title="Create budget"
            class="btn btn-primary btn-sm"
          >
            + Budget
          </button>
        </div>
      </div>

      <div class="rounded-2xl border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] p-5 shadow-[0_16px_32px_-24px_var(--fin-glass-shadow)] sm:p-6">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]">Active budgets</p>
            <h2 class="mt-1 text-xl font-semibold text-[color:var(--fin-text)]">Budget status</h2>
          </div>
          <div class="flex flex-wrap items-center gap-2">
            <span class="inline-flex items-center rounded-full border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-3 py-1 text-[11px] font-medium text-[color:var(--fin-muted)]">
              <%= current_month_range_label() %>
            </span>
            <span class="text-xs font-semibold text-[color:var(--fin-muted)]"><%= money_totals(@budget_remaining_totals) %> remaining</span>
          </div>
        </div>
        <p class="mt-1.5 text-[11px] text-[color:var(--fin-muted)]">Each budget tracks its own period — this shows the current calendar month for reference.</p>

        <div class="mt-4 space-y-3">
          <.budget_status_card :for={status <- @budget_statuses} status={status} />
          <div :if={@budget_statuses == []} class="rounded-xl border border-dashed border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-4 text-sm text-[color:var(--fin-muted)]">
            No active budgets yet.
          </div>
        </div>
      </div>
    </section>
    """
  end

  def debts_section(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[0.72fr_1.28fr]">
      <div class="rounded-2xl border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] p-5 shadow-[0_16px_32px_-24px_var(--fin-glass-shadow)] sm:p-6">
        <p class="text-xs font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]">Obligations</p>
        <h2 class="mt-1 text-xl font-semibold text-[color:var(--fin-text)]">Debts</h2>
        <div class="mt-5">
          <button
            type="button"
            phx-click="open_focus_panel"
            phx-value-panel="debt"
            aria-label="Add debt"
            title="Add debt"
            class="btn btn-primary btn-sm"
          >
            + Debt
          </button>
        </div>

        <div class="mt-5 space-y-3">
          <div :if={@debts == []} class="rounded-xl border border-dashed border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-4 text-sm text-[color:var(--fin-muted)]">
            Add debts to compare payoff strategies.
          </div>

          <.debt_card :for={debt <- @debts} debt={debt} payment_form={@payment_form} payment_form_debt_id={@payment_form_debt_id} />
        </div>
      </div>

      <div class="rounded-2xl border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] p-5 shadow-[0_16px_32px_-24px_var(--fin-glass-shadow)] sm:p-6">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]">Payoff comparison</p>
            <h2 class="mt-1 text-xl font-semibold text-[color:var(--fin-text)]">Snowball vs avalanche</h2>
          </div>
          <button type="button" phx-click="generate_plans" class="btn btn-primary btn-xs">Refresh</button>
        </div>

        <div class="mt-5 grid gap-4 lg:grid-cols-2">
          <.plan_card :for={plan <- @comparison} plan={plan} debt_currencies={@debt_currencies} />
          <div :if={@comparison == []} class="rounded-xl border border-dashed border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-4 text-sm text-[color:var(--fin-muted)] lg:col-span-2">
            Generate plans to compare payoff order, payoff month, and estimated interest.
          </div>
        </div>

        <div class="mt-6">
          <p class="text-xs font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]">Saved plans</p>
          <div class="mt-3 space-y-2">
            <div :if={@plans == []} class="rounded-xl border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-4 text-sm text-[color:var(--fin-muted)]">
              No saved payoff plans yet.
            </div>
            <div :for={plan <- @plans} class="flex items-center justify-between gap-4 rounded-xl border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-4">
              <div>
                <p class="font-semibold text-[color:var(--fin-text)]"><%= plan.name %></p>
                <p class="mt-1 text-xs text-[color:var(--fin-muted)]">
                  <%= String.capitalize(plan.strategy) %> · <%= plan_money(plan.monthly_amount, @debt_currencies) %>
                </p>
              </div>
              <span class="text-xs font-semibold text-[var(--tone-income)]"><%= format_date(plan.target_payoff_date) %></span>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  def insights_section(assigns) do
    ~H"""
    <section class="grid gap-5 lg:grid-cols-2">
      <div class="rounded-2xl border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] p-5 shadow-[0_16px_32px_-24px_var(--fin-glass-shadow)] sm:p-6">
        <p class="text-xs font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]">Signals</p>
        <h2 class="mt-1 text-xl font-semibold text-[color:var(--fin-text)]">Financial health</h2>

        <div class="mt-5 space-y-3">
          <.status_row label="Debt-to-income" value={"#{@health.debt_to_income_ratio}%"} />
          <.status_row label="Minimum payment burden" value={"#{@health.minimum_payment_burden}%"} />
          <.status_row label="Monthly debt minimums" value={money_totals(@minimum_debt_payment_totals)} />
          <.status_row label="Current free cash flow" value={money_totals(@current_month_summary_totals.balance)} />
        </div>
      </div>

      <div class="rounded-2xl border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] p-5 shadow-[0_16px_32px_-24px_var(--fin-glass-shadow)] sm:p-6">
        <p class="text-xs font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]">Reading guide</p>
        <h2 class="mt-1 text-xl font-semibold text-[color:var(--fin-text)]">How to read this snapshot</h2>
        <div class="mt-5 space-y-3 text-sm leading-6 text-[color:var(--fin-muted)]">
          <p>Health metrics reflect confirmed transactions in the active scope.</p>
          <p>Warnings call out pressure points worth reviewing before they become problems.</p>
        </div>
      </div>

      <div class="rounded-2xl border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] p-5 shadow-[0_16px_32px_-24px_var(--fin-glass-shadow)] sm:p-6 lg:col-span-2">
        <p class="text-xs font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]">Warnings</p>
        <div class="mt-4 space-y-2">
          <div :for={warning <- @health.warnings} class="rounded-lg border border-[color:var(--fin-border)] bg-[color-mix(in_srgb,var(--tone-review)_14%,transparent)] p-3 text-sm text-[var(--tone-review)]">
            <%= warning %>
          </div>
          <div :if={@health.warnings == []} class="rounded-lg border border-[color:var(--fin-border)] bg-[color-mix(in_srgb,var(--tone-income)_14%,transparent)] p-3 text-sm text-[var(--tone-income)]">
            No warnings in the current snapshot.
          </div>
        </div>
      </div>
    </section>
    """
  end

  @doc """
  Flat light card — the Finance 2.0 surface. Ivory background, hairline
  border, soft walnut shadow. Replaces the glass panel across finance.
  """
  attr :class, :any, default: nil
  attr :padded, :boolean, default: true
  slot :inner_block, required: true

  def fin_card(assigns) do
    ~H"""
    <div class={[
      "rounded-2xl border border-[color:var(--fin-border)] bg-[color:var(--fin-card)] shadow-[0_16px_32px_-24px_var(--fin-glass-shadow)]",
      @padded && "p-5 sm:p-6",
      @class
    ]}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  attr :tone, :string, default: "muted"
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def fin_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-[11px] font-semibold",
      tone_class(@tone, :soft),
      @class
    ]}>
      <%= render_slot(@inner_block) %>
    </span>
    """
  end

  @doc """
  TailAdmin-style stat card: icon chip, muted label, large value, optional
  delta badge and footnote.
  """
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :tone, :string, default: "muted"
  attr :icon, :string, default: nil
  attr :delta, :string, default: nil
  attr :delta_tone, :string, default: "muted"
  attr :note, :any, default: nil
  slot :inner_block

  def fin_stat_card(assigns) do
    ~H"""
    <.fin_card class="p-5">
      <div class="flex items-start justify-between gap-3">
        <span
          :if={@icon}
          class={["inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-xl", tone_class(@tone, :soft)]}
        >
          <.icon name={@icon} class="h-5 w-5" />
        </span>
        <.fin_badge :if={@delta} tone={@delta_tone}><%= @delta %></.fin_badge>
      </div>
      <p class="mt-4 text-xs font-semibold uppercase tracking-[0.14em] text-[color:var(--fin-muted)]"><%= @label %></p>
      <p class="mt-1 font-mono text-[1.45rem] font-semibold leading-none tracking-[-0.03em] text-[color:var(--fin-text)]">
        <%= @value %>
      </p>
      <p :if={@note} class="mt-2 text-xs leading-5 text-[color:var(--fin-muted)]"><%= @note %></p>
      <%= render_slot(@inner_block) %>
    </.fin_card>
    """
  end

  @doc """
  TailAdmin-style table. Columns via `:col` slots with a `label`; rows is any
  enumerable. Wrap in `fin_card` (padded={false}) or use standalone.
  """
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil
  attr :class, :any, default: nil

  slot :col, required: true do
    attr :label, :string
    attr :class, :string
  end

  slot :empty

  def fin_table(assigns) do
    ~H"""
    <div class={["overflow-x-auto", @class]}>
      <table class="w-full text-left text-sm">
        <thead>
          <tr class="border-b border-[color:var(--fin-border)]">
            <th
              :for={col <- @col}
              class={["px-4 py-3 text-[11px] font-semibold uppercase tracking-[0.14em] text-[color:var(--fin-muted)]", col[:class]]}
            >
              <%= col[:label] %>
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[color:var(--fin-border)]">
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class="transition hover:bg-[color:var(--fin-surface)]"
          >
            <td :for={col <- @col} class={["px-4 py-3 align-middle text-[color:var(--fin-text)]", col[:class]]}>
              <%= render_slot(col, row) %>
            </td>
          </tr>
        </tbody>
      </table>
      <div :if={@rows == [] && @empty != []} class="px-4 py-8 text-center text-sm text-[color:var(--fin-muted)]">
        <%= render_slot(@empty) %>
      </div>
    </div>
    """
  end

  @chart_income_color "#12b76a"
  @chart_expense_color "#f04438"
  @chart_budget_color "#465fff"
  @chart_review_color "#f79009"
  @chart_muted_color "#667085"
  @chart_border_color "#e4e7ec"
  @chart_fallback_palette ["#465fff", "#f79009", "#12b76a", "#f04438", "#98a2b3", "#7a5af8"]

  attr :id, :string, required: true
  attr :cashflow_months, :list, required: true
  attr :class, :any, default: nil

  def cashflow_chart(assigns) do
    options = %{
      chart: %{
        type: "bar",
        height: 320,
        stacked: true,
        fontFamily: "inherit",
        toolbar: %{show: false},
        zoom: %{enabled: false},
        foreColor: @chart_muted_color
      },
      series: [
        %{name: "Income", data: Enum.map(assigns.cashflow_months, &chart_number(&1.income))},
        %{name: "Expense", data: Enum.map(assigns.cashflow_months, &chart_number(&1.expenses))}
      ],
      colors: [@chart_income_color, @chart_expense_color],
      plotOptions: %{
        bar: %{columnWidth: "36%", borderRadius: 5, borderRadiusApplication: "end"}
      },
      dataLabels: %{enabled: false},
      grid: %{borderColor: @chart_border_color, strokeDashArray: 4},
      xaxis: %{
        categories: Enum.map(assigns.cashflow_months, & &1.label),
        axisBorder: %{show: false},
        axisTicks: %{show: false}
      },
      legend: %{show: true, position: "top", horizontalAlign: "right", markers: %{size: 5}},
      tooltip: %{theme: "light"}
    }

    assigns = assign(assigns, :payload, chart_payload(options))

    ~H"""
    <div id={@id} phx-hook="ApexChart" data-chart={@payload} class={@class} style="min-height: 320px">
      <div data-chart-target phx-update="ignore" id={@id <> "-target"}></div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :breakdown, :list, required: true
  attr :class, :any, default: nil

  def spending_donut(assigns) do
    colors =
      assigns.breakdown
      |> Enum.with_index()
      |> Enum.map(fn {slice, idx} ->
        slice.color || Enum.at(@chart_fallback_palette, rem(idx, length(@chart_fallback_palette)))
      end)

    options = %{
      chart: %{type: "donut", height: 300, fontFamily: "inherit", foreColor: @chart_muted_color},
      series: Enum.map(assigns.breakdown, &chart_number(&1.amount)),
      labels: Enum.map(assigns.breakdown, & &1.name),
      colors: colors,
      stroke: %{colors: ["#ffffff"], width: 2},
      dataLabels: %{enabled: false},
      plotOptions: %{pie: %{donut: %{size: "72%"}}},
      legend: %{show: true, position: "bottom", markers: %{size: 5}},
      tooltip: %{theme: "light"}
    }

    assigns = assign(assigns, :payload, chart_payload(options))

    ~H"""
    <div id={@id} phx-hook="ApexChart" data-chart={@payload} class={@class} style="min-height: 300px">
      <div data-chart-target phx-update="ignore" id={@id <> "-target"}></div>
    </div>
    """
  end

  defp chart_payload(options), do: Jason.encode!(options)

  defp chart_number(%Decimal{} = value), do: value |> Decimal.round(2) |> Decimal.to_float()
  defp chart_number(value) when is_number(value), do: value
  defp chart_number(_), do: 0

  defp tone_chart_color("income"), do: @chart_income_color
  defp tone_chart_color("expense"), do: @chart_expense_color
  defp tone_chart_color("budget"), do: @chart_budget_color
  defp tone_chart_color("debt"), do: @chart_review_color
  defp tone_chart_color("review"), do: @chart_review_color
  defp tone_chart_color(_tone), do: @chart_muted_color

  def hero_rate_value(nil), do: "—"
  def hero_rate_value(rate), do: "#{Float.round(rate / 1, 1)}%"

  @doc """
  "My Cards" visual, TailAdmin card-face anatomy adapted to real account
  data: contactless mark + status badge + brand line on top, account name as
  the cardholder line, and a Number / Currency / Kind field row. No fake
  card details — everything comes from finance_accounts.
  """
  attr :account, :map, required: true

  def account_card(assigns) do
    ~H"""
    <div class="relative overflow-hidden rounded-2xl bg-[linear-gradient(135deg,#1d2939_0%,#101828_55%,#0c111d_100%)] p-5 text-[#ffffff] shadow-[0_20px_36px_-24px_rgba(12,17,29,0.55)]">
      <div class="flex items-center justify-between gap-3">
        <div class="flex items-center gap-2.5">
          <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" class="h-5 w-5 text-[#d0d5dd]/90">
            <path d="M6.5 9a7.5 7.5 0 0 1 0 6" />
            <path d="M10 6.8a12 12 0 0 1 0 10.4" />
            <path d="M13.5 4.8a16.5 16.5 0 0 1 0 14.4" />
          </svg>
          <span class={[
            "rounded-full px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide",
            @account.status == "active" && "bg-[#12b76a]/20 text-[#6ce9a6]",
            @account.status != "active" && "bg-[#ffffff]/15 text-[#ffffff]/70"
          ]}>
            <%= if @account.status == "active", do: "Active", else: "Archived" %>
          </span>
        </div>
        <span class="truncate text-[11px] font-semibold uppercase tracking-[0.18em] text-[#ffffff]/65">
          <%= @account.institution || "IziHub" %>
        </span>
      </div>

      <p class="mt-7 truncate text-base font-semibold"><%= @account.name %></p>
      <p class="mt-1.5 font-mono text-xl font-semibold tracking-tight">
        <%= money(@account.current_balance, @account.currency) %>
      </p>

      <div class="mt-5 grid grid-cols-3 gap-3 text-[11px]">
        <div>
          <p class="uppercase tracking-wide text-[#ffffff]/55">Number</p>
          <p class="mt-1 font-mono font-semibold tracking-[0.14em]">•••• <%= account_card_mask(@account) %></p>
        </div>
        <div>
          <p class="uppercase tracking-wide text-[#ffffff]/55">Currency</p>
          <p class="mt-1 font-mono font-semibold"><%= @account.currency %></p>
        </div>
        <div>
          <p class="uppercase tracking-wide text-[#ffffff]/55">Kind</p>
          <p class="mt-1 font-semibold"><%= account_kind_label(@account.kind) %></p>
        </div>
      </div>
    </div>
    """
  end

  defp account_card_mask(%{id: id}), do: id |> to_string() |> String.slice(-4, 4)

  def account_kind_label(kind) do
    Enum.find_value(account_kind_options(), kind, fn {label, value} ->
      value == kind && label
    end)
  end

  attr :active_section, :string, required: true
  attr :section, :string, required: true
  attr :label, :string, required: true

  def section_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="show_section"
      phx-value-section={@section}
      class={[
        "shrink-0 rounded-2xl px-3.5 py-2 text-sm font-semibold transition xl:flex xl:w-full xl:items-center xl:justify-start xl:px-4 xl:py-3",
        @active_section == @section && "bg-[#465fff] text-[#ffffff] shadow-sm xl:bg-[color-mix(in_srgb,var(--fin-accent)_12%,transparent)] xl:text-[var(--fin-accent)]",
        @active_section != @section && "border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] text-[color:var(--fin-muted)] hover:bg-[color:var(--fin-surface)] hover:text-[color:var(--fin-text)] xl:border-transparent"
      ]}
    >
      <%= @label %>
    </button>
    """
  end

  attr :active_section, :string, required: true
  attr :section, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true

  def side_nav_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="show_section"
      phx-value-section={@section}
      class={[
        "flex w-full items-center gap-3 rounded-xl px-4 py-3 text-left transition",
        @active_section == @section && "bg-[color-mix(in_srgb,var(--fin-accent)_12%,transparent)] font-semibold text-[var(--fin-accent)]",
        @active_section != @section && "text-[color:var(--fin-muted)] hover:bg-[color:var(--fin-surface)] hover:text-[color:var(--fin-text)]"
      ]}
    >
      <.icon name={@icon} class="h-[17px] w-[17px]" />
      <span><%= @label %></span>
    </button>
    """
  end

  attr :title, :string, required: true
  attr :month, :map, required: true

  def month_card(assigns) do
    ~H"""
    <div class="rounded-xl border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-4">
      <p class="text-sm font-semibold text-[color:var(--fin-text)]"><%= @title %></p>
      <p class="mt-1 text-xs text-[color:var(--fin-muted)]"><%= format_date(@month.start_date) %> to <%= format_date(@month.end_date) %></p>
      <div class="mt-4 space-y-2 text-sm">
        <.status_row label="Income" value={money(@month.income, @default_currency)} />
        <.status_row label="Expenses" value={money(@month.expenses, @default_currency)} />
        <.status_row label="Free cash flow" value={money(@month.free_cash_flow, @default_currency)} />
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :left, :any, required: true
  attr :right, :any, required: true
  attr :active, :boolean, default: false

  def comparison_bar(assigns) do
    max_amount =
      [assigns.left, assigns.right, Decimal.new("1")]
      |> Enum.map(&decimal_to_float/1)
      |> Enum.max()

    assigns =
      assigns
      |> assign(:left_height, scaled_bar_height(assigns.left, max_amount))
      |> assign(:right_height, scaled_bar_height(assigns.right, max_amount))

    ~H"""
    <div class="flex flex-col items-center gap-3">
      <div class="flex h-[11rem] items-end gap-2.5">
        <div class="w-5 rounded-t-[0.9rem] bg-[var(--tone-income)]" style={"height: #{@left_height}px"} />
        <div class="w-5 rounded-t-[0.9rem] bg-[var(--tone-expense)]" style={"height: #{@right_height}px"} />
      </div>
      <span class={["text-xs", @active && "font-semibold text-[color:var(--fin-text)]", !@active && "text-[color:var(--fin-muted)]"]}><%= @label %></span>
    </div>
    """
  end

  attr :transaction, Transaction, required: true

  def transaction_table_row(assigns) do
    ~H"""
    <div class="grid grid-cols-[minmax(0,1.2fr)_auto_auto] items-center gap-3 px-5 py-4">
      <div class="min-w-0">
        <p class="truncate font-medium text-[color:var(--fin-text)]"><%= @transaction.description || review_title(@transaction) %></p>
        <p class="mt-1 text-xs text-[color:var(--fin-muted)]">
          <%= category_name(@transaction.category) %> · <%= format_date(@transaction.transaction_date) %>
        </p>
      </div>
      <p class={["text-right font-mono text-sm font-semibold", tone_class(@transaction.type)]}>
        <%= signed_money(@transaction) %>
      </p>
      <p class="truncate text-right font-mono text-sm text-[color:var(--fin-muted)]">
        <%= @transaction.account && @transaction.account.name || "Unassigned" %>
      </p>
    </div>
    """
  end

  attr :status, :map, required: true

  def budget_progress_row(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between gap-4 text-sm">
        <span class="font-medium text-[color:var(--fin-text)]"><%= @status.budget.name %></span>
        <span class="font-mono text-[12px] text-[color:var(--fin-muted)]"><%= money(@status.spent, @status.budget.currency) %> / <%= money(@status.budget.amount, @status.budget.currency) %></span>
      </div>
      <div class="mt-2.5 h-1.5 overflow-hidden rounded-full bg-[color:var(--fin-surface)]">
        <div class={["h-full rounded-full", tone_class(budget_state_tone(@status), :bar)]} style={"width: #{budget_remaining_pct(@status.percentage)}%"} />
      </div>
    </div>
    """
  end

  attr :transaction, Transaction, required: true
  attr :compact, :boolean, default: false

  def transaction_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-3 rounded-lg border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-3">
      <div class="min-w-0">
        <div class="flex flex-wrap items-center gap-2">
          <span class={["text-sm font-semibold", tone_class(@transaction.type)]}>
            <%= signed_money(@transaction) %>
          </span>
          <span class="text-sm font-semibold text-[color:var(--fin-text)]"><%= @transaction.description || "Transaction" %></span>
        </div>
        <p class="mt-1 text-xs text-[color:var(--fin-muted)]">
          <%= format_date(@transaction.transaction_date) %>
          <%= if @transaction.category, do: " · #{@transaction.category.name}" %>
          <%= if @transaction.account, do: " · #{@transaction.account.name}" %>
          <%= if @transaction.payment_method, do: " · #{format_kind(@transaction.payment_method)}" %>
        </p>
      </div>
      <div class="flex items-center gap-2">
        <span :if={show_status_badge?(@transaction)} class={["rounded-full px-2 py-1 text-[11px] font-semibold", tone_class(transaction_status_tone(@transaction.status), :soft)]}>
          <%= transaction_status_label(@transaction.status) %>
        </span>
        <button :if={!@compact} type="button" phx-click="open_edit_transaction" phx-value-id={@transaction.id} class="btn btn-secondary btn-xs">
          Edit
        </button>
        <button
          :if={!@compact}
          type="button"
          phx-click="delete_transaction"
          phx-value-id={@transaction.id}
          class="btn btn-ghost btn-xs text-[var(--tone-expense)]"
        >
          Delete
        </button>
      </div>
    </div>
    """
  end

  attr :transaction, Transaction, required: true
  attr :compact, :boolean, default: false

  def review_row(assigns) do
    ~H"""
    <div class="rounded-lg border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-4">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div class="min-w-0">
          <div class="flex flex-wrap items-center gap-2">
            <span class={["text-sm font-semibold", tone_class(@transaction.type)]}>
              <%= signed_money(@transaction) %>
            </span>
            <span class="text-sm font-semibold text-[color:var(--fin-text)]"><%= review_title(@transaction) %></span>
            <span class="rounded-full bg-[color-mix(in_srgb,var(--tone-review)_16%,transparent)] px-2 py-1 text-[11px] font-semibold text-[var(--tone-review)]">
              <%= source_label(@transaction.source) %>
            </span>
          </div>
          <p class="mt-1 text-xs text-[color:var(--fin-muted)]">
            <%= format_date(@transaction.transaction_date) %>
            <%= if @transaction.merchant, do: " · #{@transaction.merchant}" %>
            <%= if @transaction.review_reason, do: " · #{@transaction.review_reason}" %>
          </p>
          <p :if={@transaction.raw_description} class="mt-2 text-sm text-[color:var(--fin-muted)]"><%= @transaction.raw_description %></p>
        </div>

        <div class="flex items-center gap-2">
          <span :if={is_number(@transaction.confidence)} class={["rounded-full px-2 py-1 text-[11px] font-semibold", tone_class(confidence_tone(@transaction.confidence), :soft)]}>
            <%= confidence_label(@transaction.confidence) %>
          </span>
          <div :if={!@compact} class="flex gap-2">
            <button type="button" phx-click="confirm_transaction" phx-value-id={@transaction.id} class="btn btn-primary btn-xs">
              Confirm
            </button>
            <button type="button" phx-click="open_edit_transaction" phx-value-id={@transaction.id} class="btn btn-secondary btn-xs">
              Edit
            </button>
            <button type="button" phx-click="ignore_transaction" phx-value-id={@transaction.id} class="btn btn-ghost btn-xs text-[var(--tone-expense)]">
              Ignore
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :status, :map, required: true

  def budget_status_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-4">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p class="font-semibold text-[color:var(--fin-text)]"><%= @status.budget.name %></p>
          <p class="mt-1 text-xs text-[color:var(--fin-muted)]">
            <%= category_name(@status.budget.category) %> · <%= String.capitalize(@status.budget.period) %>
          </p>
        </div>
        <span class={["rounded-full px-2.5 py-1 text-xs font-semibold", tone_class(budget_state_tone(@status), :soft)]}>
          <%= budget_state_label(@status) %>
        </span>
      </div>

      <div class="mt-4 h-2 overflow-hidden rounded-full bg-[color:var(--fin-surface)]">
        <div class={["h-full rounded-full", tone_class(budget_state_tone(@status), :bar)]} style={"width: #{budget_remaining_pct(@status.percentage)}%"} />
      </div>

      <div class="mt-3 grid grid-cols-3 gap-2 text-xs">
        <div>
          <p class="text-[color:var(--fin-muted)]">Spent</p>
          <p class="mt-1 font-semibold text-[color:var(--fin-text)]"><%= money(@status.spent, @status.budget.currency) %></p>
        </div>
        <div>
          <p class="text-[color:var(--fin-muted)]">Remaining</p>
          <p class="mt-1 font-semibold text-[color:var(--fin-text)]"><%= money(@status.remaining, @status.budget.currency) %></p>
        </div>
        <div>
          <p class="text-[color:var(--fin-muted)]">Used</p>
          <p class="mt-1 font-semibold text-[color:var(--fin-text)]"><%= Float.round(@status.percentage, 1) %>%</p>
        </div>
      </div>
    </div>
    """
  end

  attr :debt, :any, required: true
  attr :payment_form, :any, required: true
  attr :payment_form_debt_id, :string, default: nil

  def debt_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-4">
      <div class="flex items-start justify-between gap-4">
        <div>
          <p class="font-semibold text-[color:var(--fin-text)]"><%= @debt.name %></p>
          <p class="mt-1 text-xs text-[color:var(--fin-muted)]">
            <%= format_kind(@debt.kind) %><%= if @debt.provider, do: " with #{@debt.provider}" %>
          </p>
        </div>
        <div class="flex flex-wrap justify-end gap-2">
          <button type="button" phx-click="open_payment_form" phx-value-id={@debt.id} class="btn btn-secondary btn-xs">
            Record payment
          </button>
          <button type="button" phx-click="archive_debt" phx-value-id={@debt.id} class="btn btn-ghost btn-xs text-[var(--tone-expense)]">
            Archive
          </button>
        </div>
      </div>

      <div class="mt-4 grid grid-cols-3 gap-3 text-sm">
        <div>
          <p class="text-[11px] font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]">Balance</p>
          <p class="mt-1 font-semibold text-[color:var(--fin-text)]"><%= money(@debt.current_balance, @debt.currency) %></p>
        </div>
        <div>
          <p class="text-[11px] font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]">Minimum</p>
          <p class="mt-1 font-semibold text-[color:var(--fin-text)]"><%= money(@debt.minimum_payment, @debt.currency) %></p>
        </div>
        <div>
          <p class="text-[11px] font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]">APR</p>
          <p class="mt-1 font-semibold text-[color:var(--fin-text)]"><%= apr(@debt.apr) %></p>
        </div>
      </div>

      <.form :if={@payment_form_debt_id == @debt.id} for={@payment_form} phx-submit="record_payment" class="mt-4 rounded-lg border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-4">
        <input type="hidden" name="debt_id" value={@debt.id} />
        <div class="grid gap-3 md:grid-cols-2">
          <.finance_input form={@payment_form} field={:amount} label="Payment amount" placeholder="100.00" type="number" step="0.01" />
          <.finance_input form={@payment_form} field={:payment_date} label="Payment date" type="date" />
          <.finance_select form={@payment_form} field={:kind} label="Kind" options={payment_kind_options()} />
          <label class="flex items-center gap-2 rounded-lg border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-4 py-3 text-sm font-semibold text-[color:var(--fin-text)]">
            <input type="hidden" name="payment[create_expense_transaction]" value="false" />
            <input type="checkbox" name="payment[create_expense_transaction]" value="true" checked class="h-4 w-4 rounded border-[color:var(--fin-border)] text-[color:var(--fin-text)]" />
            Create expense transaction
          </label>
          <div class="md:col-span-2">
            <.finance_input form={@payment_form} field={:notes} label="Notes" placeholder="Optional payment note" />
          </div>
        </div>

        <div class="mt-4 flex justify-end gap-2">
          <button type="button" phx-click="close_payment_form" class="btn btn-ghost btn-xs">Cancel</button>
          <button type="submit" class="btn btn-primary btn-xs">Record payment</button>
        </div>
      </.form>

      <div :if={@debt.payments != []} class="mt-4 rounded-lg bg-[color:var(--fin-surface)] p-3">
        <p class="text-[11px] font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]">Recent payments</p>
        <div class="mt-2 space-y-2">
          <div :for={payment <- @debt.payments} class="flex items-center justify-between gap-3 text-sm">
            <span class="text-[color:var(--fin-muted)]">
              <%= format_date(payment.payment_date) %> · <%= format_kind(payment.kind) %>
            </span>
            <span class="font-semibold text-[color:var(--fin-text)]"><%= money(payment.amount, @debt.currency) %></span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  def status_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-4 border-b border-[color:var(--fin-border)] py-2 last:border-b-0">
      <span class="text-sm text-[color:var(--fin-muted)]"><%= @label %></span>
      <span class="text-sm font-semibold text-[color:var(--fin-text)]"><%= @value %></span>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :field, :atom, required: true
  attr :label, :string, required: true
  attr :type, :string, default: "text"
  attr :placeholder, :string, default: nil
  attr :step, :string, default: nil

  def finance_input(assigns) do
    field = assigns.form[assigns.field]
    assigns = assign(assigns, :field_data, field)

    ~H"""
    <div>
      <label for={@field_data.id} class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]">
        <%= @label %>
      </label>
      <input
        id={@field_data.id}
        name={@field_data.name}
        value={@field_data.value}
        type={@type}
        placeholder={@placeholder}
        step={@step}
        class="w-full rounded-lg border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-3 py-2.5 text-sm text-[color:var(--fin-text)] outline-none transition focus:border-[var(--fin-accent)] focus:ring-2 focus:ring-[color-mix(in_srgb,var(--fin-accent)_25%,transparent)]"
      />
      <p :for={error <- @field_data.errors} class="mt-1 text-xs text-[var(--tone-expense)]"><%= translate_error(error) %></p>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :field, :atom, required: true
  attr :label, :string, required: true
  attr :options, :list, required: true

  def finance_select(assigns) do
    field = assigns.form[assigns.field]
    assigns = assign(assigns, :field_data, field)

    ~H"""
    <div>
      <label for={@field_data.id} class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]">
        <%= @label %>
      </label>
      <select
        id={@field_data.id}
        name={@field_data.name}
        class="w-full rounded-lg border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] px-3 py-2.5 text-sm text-[color:var(--fin-text)] outline-none transition focus:border-[var(--fin-accent)] focus:ring-2 focus:ring-[color-mix(in_srgb,var(--fin-accent)_25%,transparent)]"
      >
        <option :for={{label, value} <- @options} value={value} selected={selected?(@field_data.value, value)}>
          <%= label %>
        </option>
      </select>
      <p :for={error <- @field_data.errors} class="mt-1 text-xs text-[var(--tone-expense)]"><%= translate_error(error) %></p>
    </div>
    """
  end

  attr :plan, :map, required: true
  attr :debt_currencies, :list, default: []

  def plan_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-[color:var(--fin-border)] bg-[color:var(--fin-surface)] p-4 shadow-sm">
      <div class="flex items-start justify-between gap-4">
        <div>
          <p class="text-lg font-semibold text-[color:var(--fin-text)]"><%= String.capitalize(@plan.strategy) %></p>
          <p class="mt-1 text-xs text-[color:var(--fin-muted)]"><%= if @plan.feasible?, do: "Feasible with current cash flow", else: "Needs more cash flow" %></p>
        </div>
        <button type="button" phx-click="save_plan" phx-value-strategy={@plan.strategy} class="btn btn-secondary btn-xs">
          Save
        </button>
      </div>

      <div class="mt-4 space-y-2">
        <.status_row label="Monthly amount" value={plan_money(@plan.monthly_amount, @debt_currencies)} />
        <.status_row label="Estimated interest" value={plan_money(@plan.estimated_interest, @debt_currencies)} />
        <.status_row label="Payoff months" value={to_string(@plan.payoff_months)} />
        <.status_row label="Payoff date" value={format_date(@plan.target_payoff_date)} />
      </div>

      <div class="mt-4 rounded-lg bg-[color:var(--fin-surface)] p-3">
        <p class="text-[11px] font-semibold uppercase tracking-wide text-[color:var(--fin-muted)]">Order</p>
        <p class="mt-1 text-sm text-[color:var(--fin-text)]"><%= payoff_order(@plan.payoff_order) %></p>
      </div>
    </div>
    """
  end

  def transaction_type_options, do: [{"Expense", "expense"}, {"Income", "income"}]

  def payment_method_options do
    [
      {"Not set", ""},
      {"Cash", "cash"},
      {"Card", "card"},
      {"Bank transfer", "bank_transfer"},
      {"Digital wallet", "digital_wallet"},
      {"Check", "check"},
      {"Other", "other"}
    ]
  end

  def account_kind_options do
    [
      {"Checking", "checking"},
      {"Savings", "savings"},
      {"Cash", "cash"},
      {"Credit card", "credit_card"},
      {"Investment", "investment"},
      {"Loan", "loan"},
      {"Other", "other"}
    ]
  end

  def budget_period_options do
    [
      {"Monthly", "monthly"},
      {"Weekly", "weekly"},
      {"Daily", "daily"},
      {"Quarterly", "quarterly"},
      {"Yearly", "yearly"},
      {"Custom", "custom"}
    ]
  end

  def currency_options do
    [
      {"Dominican peso (DOP)", "DOP"},
      {"US dollar (USD)", "USD"}
    ]
  end

  def category_options(categories) do
    [{"Uncategorized", ""}] ++ Enum.map(categories, &{&1.name, &1.id})
  end

  def account_options(accounts) do
    [{"Not set", ""}] ++
      Enum.map(accounts, &{"#{&1.name} (#{normalize_currency(&1.currency)})", &1.id})
  end

  def debt_kind_options do
    [
      {"Credit card", "credit_card"},
      {"Loan", "loan"},
      {"Student loan", "student_loan"},
      {"Mortgage", "mortgage"},
      {"Medical", "medical"},
      {"Personal", "personal"},
      {"Other", "other"}
    ]
  end

  def payment_kind_options do
    [
      {"Extra", "extra"},
      {"Minimum", "minimum"},
      {"Settlement", "settlement"},
      {"Adjustment", "adjustment"}
    ]
  end

  def transaction_form_title(nil), do: "Add transaction"
  def transaction_form_title(_id), do: "Edit transaction"

  def transaction_submit(nil), do: "create_transaction"
  def transaction_submit(_id), do: "update_transaction"

  def transaction_submit_label(nil, _status), do: "Save transaction"
  def transaction_submit_label(_id, "pending_review"), do: "Save and confirm"
  def transaction_submit_label(_id, _status), do: "Save changes"

  def money(%Decimal{} = amount, currency) do
    rounded = Decimal.round(amount, 2)

    case Decimal.compare(rounded, Decimal.new("0")) do
      :lt -> "-#{currency_prefix(currency)}#{group_thousands(Decimal.abs(rounded))}"
      _ -> "#{currency_prefix(currency)}#{group_thousands(rounded)}"
    end
  end

  def money(nil, currency), do: "#{currency_prefix(currency)}0.00"

  defp group_thousands(%Decimal{} = amount) do
    [int_part, dec_part] = amount |> Decimal.to_string() |> String.split(".", parts: 2)

    grouped_int =
      int_part
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.map_join(",", &Enum.join/1)
      |> String.reverse()

    grouped_int <> "." <> dec_part
  end

  def money_totals([]), do: money(nil, @default_currency)

  def money_totals(totals) do
    totals
    |> sort_currency_totals()
    |> Enum.map_join(" · ", fn %{currency: currency, amount: amount} ->
      money(amount, currency)
    end)
  end

  def signed_money(%Transaction{type: "income", amount: amount} = transaction),
    do: "+#{money(amount, transaction_currency(transaction))}"

  def signed_money(%Transaction{amount: amount} = transaction),
    do: "-#{money(amount, transaction_currency(transaction))}"

  def signed_decimal(%Decimal{} = amount, currency) do
    case Decimal.compare(amount, Decimal.new("0")) do
      :lt -> "-#{money(Decimal.abs(amount), currency)}"
      _ -> "+#{money(amount, currency)}"
    end
  end

  def signed_money_totals([]), do: "+#{money(nil, @default_currency)}"

  def signed_money_totals(totals) do
    totals
    |> sort_currency_totals()
    |> Enum.map_join(" · ", fn %{currency: currency, amount: amount} ->
      signed_decimal(amount, currency)
    end)
  end

  def plan_money(amount, [currency]), do: money(amount, currency)

  def plan_money(_amount, currencies) when length(currencies) > 1,
    do: mixed_currency_label(currencies)

  def plan_money(amount, _currencies), do: money(amount, @default_currency)

  def apr(nil), do: "Missing"
  def apr(%Decimal{} = value), do: "#{Decimal.round(value, 2)}%"

  def selected?(nil, ""), do: true
  def selected?(value, option), do: to_string(value || "") == option

  def format_date(nil), do: "Not set"
  def format_date(%Date{} = date), do: Calendar.strftime(date, "%b %-d, %Y")

  def format_kind(nil), do: "Not set"
  def format_kind(kind), do: kind |> String.replace("_", " ") |> String.capitalize()

  def category_name(nil), do: "All spending"
  def category_name(category), do: category.name

  def transaction_currency(%Transaction{account: %Account{currency: currency}}),
    do: normalize_currency(currency)

  def transaction_currency(_transaction), do: @default_currency

  def account_summary_subtitle(account) do
    [account.institution, format_kind(account.kind), account.currency]
    |> Enum.reject(&is_nil_or_empty/1)
    |> Enum.join(" · ")
  end

  def currency_totals(items, amount_fun, currency_fun) do
    items
    |> Enum.reduce(%{}, fn item, acc ->
      amount = amount_fun.(item) || Decimal.new("0")
      currency = normalize_currency(currency_fun.(item))
      Map.update(acc, currency, amount, &Decimal.add(&1, amount))
    end)
    |> Enum.map(fn {currency, amount} -> %{currency: currency, amount: amount} end)
    |> sort_currency_totals()
  end

  def currency_codes(items, currency_fun) do
    items
    |> Enum.map(&(currency_fun.(&1) |> normalize_currency()))
    |> Enum.uniq()
    |> Enum.sort_by(&currency_sort_rank/1)
  end

  def sort_currency_totals(totals) do
    Enum.sort_by(totals, fn %{currency: currency} ->
      {currency_sort_rank(currency), currency}
    end)
  end

  def mixed_currency_label(currencies) do
    "Mixed currencies (#{Enum.join(Enum.sort_by(currencies, &currency_sort_rank/1), ", ")})"
  end

  def networth_category_order, do: @networth_category_order
  def networth_category_meta(category), do: Map.fetch!(@networth_category_meta, category)

  def net_worth_visible_items(items, "all"), do: items
  def net_worth_visible_items(items, category), do: Enum.filter(items, &(&1.category == category))

  def net_worth_max_amount([]), do: 1.0

  def net_worth_max_amount(items) do
    items
    |> Enum.map(&abs(decimal_to_float(&1.amount)))
    |> Enum.max()
    |> max(1.0)
  end

  # The currency with the largest gross total (assets + liabilities) drives
  # the net worth donut — mirrors the hero card's dominant-currency pick, so
  # a single chart stays representative without needing one per currency.
  defp net_worth_dominant_allocation([]), do: nil

  defp net_worth_dominant_allocation(allocation) do
    Enum.max_by(allocation, &decimal_to_float(&1.total), fn -> nil end)
  end

  def net_worth_donut_currency(allocation) do
    case net_worth_dominant_allocation(allocation) do
      nil -> @default_currency
      %{currency: currency} -> currency
    end
  end

  defp net_worth_donut_breakdown(allocation) do
    case net_worth_dominant_allocation(allocation) do
      nil ->
        []

      %{segments: segments} ->
        segments
        |> Enum.filter(&(Decimal.compare(&1.amount, Decimal.new("0")) == :gt))
        |> Enum.map(fn segment ->
          %{
            name: networth_category_meta(segment.key).label,
            color: tone_chart_color(segment.tone),
            amount: segment.amount
          }
        end)
    end
  end

  def currency_prefix(currency) do
    case normalize_currency(currency) do
      "DOP" -> "DOP$ "
      "USD" -> "US$ "
      code -> "#{code}$ "
    end
  end

  def currency_sort_rank("DOP"), do: 0
  def currency_sort_rank("USD"), do: 1
  def currency_sort_rank(_currency), do: 2

  def normalize_currency(nil), do: @default_currency

  def normalize_currency(currency) do
    case currency |> to_string() |> String.trim() |> String.upcase() do
      "" -> @default_currency
      normalized -> normalized
    end
  end

  def payoff_order([]), do: "No active balances"
  def payoff_order(debts), do: debts |> Enum.map(& &1.name) |> Enum.join(" -> ")

  # Single source of truth for tone -> color across the finance page.
  # Each clause is a complete literal class string so Tailwind's static
  # scanner can find and generate it (interpolated/dynamic class names
  # would be invisible to the JIT scanner).
  def tone_class(tone, variant \\ :text)

  def tone_class("income", :text), do: "text-[var(--tone-income)]"
  def tone_class("cash", :text), do: "text-[var(--tone-income)]"
  def tone_class("expense", :text), do: "text-[var(--tone-expense)]"
  def tone_class("budget", :text), do: "text-[var(--tone-budget)]"
  def tone_class("debt", :text), do: "text-[var(--tone-debt)]"
  def tone_class("review", :text), do: "text-[var(--tone-review)]"
  def tone_class("muted", :text), do: "text-[var(--fin-muted)]"
  def tone_class(_tone, :text), do: "text-[var(--tone-income)]"

  def tone_class("income", :soft),
    do: "bg-[color-mix(in_srgb,var(--tone-income)_14%,transparent)] text-[var(--tone-income)]"

  def tone_class("cash", :soft),
    do: "bg-[color-mix(in_srgb,var(--tone-income)_14%,transparent)] text-[var(--tone-income)]"

  def tone_class("expense", :soft),
    do: "bg-[color-mix(in_srgb,var(--tone-expense)_14%,transparent)] text-[var(--tone-expense)]"

  def tone_class("budget", :soft),
    do: "bg-[color-mix(in_srgb,var(--fin-accent)_14%,transparent)] text-[var(--fin-accent)]"

  def tone_class("debt", :soft),
    do: "bg-[color-mix(in_srgb,var(--tone-debt)_14%,transparent)] text-[var(--tone-debt)]"

  def tone_class("review", :soft),
    do: "bg-[color-mix(in_srgb,var(--tone-review)_14%,transparent)] text-[var(--tone-review)]"

  def tone_class("muted", :soft),
    do: "bg-[color-mix(in_srgb,var(--fin-muted)_14%,transparent)] text-[var(--fin-muted)]"

  def tone_class(_tone, :soft),
    do: "bg-[color-mix(in_srgb,var(--tone-income)_14%,transparent)] text-[var(--tone-income)]"

  def tone_class("income", :bar), do: "bg-[var(--tone-income)]"
  def tone_class("cash", :bar), do: "bg-[var(--tone-income)]"
  def tone_class("expense", :bar), do: "bg-[var(--tone-expense)]"
  def tone_class("budget", :bar), do: "bg-[var(--tone-budget)]"
  def tone_class("debt", :bar), do: "bg-[var(--tone-debt)]"
  def tone_class("review", :bar), do: "bg-[var(--tone-review)]"
  def tone_class("muted", :bar), do: "bg-[var(--fin-muted)]"
  def tone_class(_tone, :bar), do: "bg-[var(--tone-income)]"

  def budget_state_tone(%{is_over: true}), do: "expense"
  def budget_state_tone(%{is_near_limit: true}), do: "review"
  def budget_state_tone(_status), do: "income"

  @doc """
  Worst-case tone across a set of budget statuses, so aggregate widgets (like
  the dashboard's "This month's budget" bar) use the same red/gold/green
  vocabulary as the per-budget cards instead of an unrelated color.
  """
  def overall_budget_tone([]), do: "budget"

  def overall_budget_tone(statuses) do
    cond do
      Enum.any?(statuses, & &1.is_over) -> "expense"
      Enum.any?(statuses, & &1.is_near_limit) -> "review"
      true -> "income"
    end
  end

  @doc """
  Bars in this app track what's left, not what's spent: they start full and
  deplete as a budget gets used, so the width is the inverse of `percentage`
  (which itself represents percent used). Clamped to 0..100.
  """
  def budget_remaining_pct(percentage) do
    percentage
    |> then(&(100 - &1))
    |> max(0)
    |> min(100)
  end

  def transaction_status_tone("pending_review"), do: "review"
  def transaction_status_tone("ignored"), do: "muted"
  def transaction_status_tone(_status), do: "income"

  def confidence_tone(confidence) when confidence >= 0.85, do: "income"
  def confidence_tone(confidence) when confidence >= 0.6, do: "review"
  def confidence_tone(_confidence), do: "expense"

  def transaction_status_label("pending_review"), do: "Pending"
  def transaction_status_label("ignored"), do: "Ignored"
  def transaction_status_label(_status), do: "Confirmed"

  def show_status_badge?(%Transaction{status: "confirmed"}), do: false
  def show_status_badge?(_transaction), do: true

  def review_title(%Transaction{description: description})
      when is_binary(description) and description != "",
      do: description

  def review_title(%Transaction{merchant: merchant}) when is_binary(merchant) and merchant != "",
    do: merchant

  def review_title(_transaction), do: "Imported transaction"

  def source_label(nil), do: "Manual"
  def source_label(source), do: format_kind(source)

  def confidence_label(confidence), do: "#{round(confidence * 100)}% confidence"

  def review_section_label(0), do: "Review"
  def review_section_label(count), do: "Review (#{count})"

  def active_section_title("overview", _pending_review_count), do: "Overview"
  def active_section_title("networth", _pending_review_count), do: "Net worth"
  def active_section_title("accounts", _pending_review_count), do: "Accounts"
  def active_section_title("transactions", _pending_review_count), do: "Transactions"
  def active_section_title("review", 0), do: "Review queue"
  def active_section_title("review", count), do: "Review queue (#{count})"
  def active_section_title("budgets", _pending_review_count), do: "Budgets"
  def active_section_title("debts", _pending_review_count), do: "Debts"
  def active_section_title("goals", _pending_review_count), do: "Savings goals"
  def active_section_title("insights", _pending_review_count), do: "Insights"

  def active_section_subtitle("overview"), do: nil
  def active_section_subtitle("networth"), do: "Everything you own minus everything you owe."
  def active_section_subtitle("accounts"), do: "Every account you're tracking, in one place."
  def active_section_subtitle("transactions"), do: nil
  def active_section_subtitle("review"), do: nil
  def active_section_subtitle("budgets"), do: nil
  def active_section_subtitle("debts"), do: nil
  def active_section_subtitle("goals"), do: "Track progress toward what you're saving for."
  def active_section_subtitle("insights"), do: nil

  def budget_metric_note([]), do: "No active budgets"
  def budget_metric_note(budgets), do: "#{length(budgets)} active"

  def expense_metric_note([]), do: "No spend yet"
  def expense_metric_note(transactions), do: "#{length(transactions)} in view"

  def pending_review_note(0), do: "Queue clear"
  def pending_review_note(1), do: "1 item waiting"
  def pending_review_note(count), do: "#{count} items waiting"

  def budget_state_label(%{is_over: true}), do: "Over"
  def budget_state_label(%{is_near_limit: true}), do: "Near limit"
  def budget_state_label(_status), do: "On track"

  def savings_goal_percentage(%{target_amount: target, saved_amount: saved}) do
    if target && Decimal.compare(target, Decimal.new("0")) == :gt do
      decimal_to_float(saved || Decimal.new("0")) / decimal_to_float(target) * 100
    else
      0.0
    end
  end

  def savings_goal_tone(%{status: "achieved"}), do: "income"
  def savings_goal_tone(_goal), do: "budget"

  def savings_goal_state_label(%{status: "achieved"}), do: "Achieved"
  def savings_goal_state_label(_goal), do: "In progress"

  def household_scope_available?(households), do: households != []

  def household_scope_aria_label([]), do: "Create a household"
  def household_scope_aria_label(_households), do: "Household finance scope"

  def household_scope_title([]), do: "Create a household"
  def household_scope_title(_households), do: "Household"

  def time_scope_title("day"), do: "Day"
  def time_scope_title("week"), do: "Week"
  def time_scope_title("month"), do: "Month"
  def time_scope_title("year"), do: "Year"
  def time_scope_title("event"), do: "Event"

  def greeting_date do
    Date.utc_today()
    |> Calendar.strftime("%A, %B %-d")
  end

  def greeting_headline(user) do
    "#{time_of_day_greeting()}, #{current_scope_name(user)}"
  end

  defp time_of_day_greeting do
    cond do
      DateTime.utc_now().hour < 12 -> "Good morning"
      DateTime.utc_now().hour < 18 -> "Good afternoon"
      true -> "Good evening"
    end
  end

  def household_toggle_event(households) do
    if household_scope_available?(households), do: "set_ownership_scope", else: "open_focus_panel"
  end

  def current_month_range_label do
    today = Date.utc_today()
    start_date = Date.beginning_of_month(today)
    end_date = Date.end_of_month(today)
    "#{Calendar.strftime(start_date, "%b %-d")} – #{Calendar.strftime(end_date, "%b %-d")}"
  end

  def current_scope_name(user) do
    user.full_name || user.username || user.email || "User"
  end

  def initials(user) do
    user
    |> current_scope_name()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
    |> String.upcase()
  end

  def due_day_label(nil), do: "Due day not set"
  def due_day_label(due_day), do: "Due on day #{due_day}"

  def selected_household_name(nil), do: "Household"
  def selected_household_name(household), do: household.name

  def household_owner?(_user, nil), do: false
  def household_owner?(user, household), do: Accounts.user_household_owner?(user, household.id)

  def household_role_label(_user, nil), do: "Personal"

  def household_role_label(user, household) do
    if household_owner?(user, household), do: "Owner", else: "Member"
  end

  def household_member_summaries(nil), do: []

  def household_member_summaries(household) do
    Enum.map(household.memberships, fn membership ->
      %{
        name: membership.user.full_name || membership.user.username || membership.user.email,
        label: membership.user.username || membership.user.email,
        role: String.capitalize(membership.role)
      }
    end)
  end

  def decimal_to_float(%Decimal{} = value), do: Decimal.to_float(value)
  def decimal_to_float(value) when is_integer(value), do: value * 1.0
  def decimal_to_float(value) when is_float(value), do: value
  def decimal_to_float(_value), do: 0.0

  def scaled_bar_height(value, max_amount) do
    value
    |> decimal_to_float()
    |> Kernel./(max(max_amount, 1.0))
    |> Kernel.*(120)
    |> round()
    |> max(12)
  end

  def focus_panel_title("transaction"), do: "Add transaction"
  def focus_panel_title("transfer"), do: "Transfer between accounts"
  def focus_panel_title("account"), do: "Add account"
  def focus_panel_title("budget"), do: "Budget setup"
  def focus_panel_title("debt"), do: "Debt setup"
  def focus_panel_title("household"), do: "Household setup"

  def is_nil_or_empty(nil), do: true
  def is_nil_or_empty(""), do: true
  def is_nil_or_empty(_value), do: false

  def translate_error({message, opts}) do
    Enum.reduce(opts, message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end

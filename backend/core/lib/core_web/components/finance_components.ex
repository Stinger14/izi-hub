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
      <.glass class="px-5 py-5 sm:px-6">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div class="space-y-2">
            <p class="text-[11px] font-semibold uppercase tracking-[0.24em] text-slate-400"><%= greeting_date() %></p>
            <h1 class="font-display text-[1.55rem] tracking-tight text-white">
              <%= active_section_title(@active_section, @pending_review_count) %>
            </h1>
            <p :if={active_section_subtitle(@active_section)} class="max-w-2xl text-sm leading-6 text-slate-400">
              <%= active_section_subtitle(@active_section) %>
            </p>
          </div>

          <div class="flex flex-wrap items-center justify-end gap-2.5">
            <div class="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.04] px-1 py-1 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)]">
              <button
                type="button"
                phx-click="set_ownership_scope"
                phx-value-scope="personal"
                aria-label="Personal finance scope"
                title="Personal finance scope"
                class={[
                  "inline-flex h-9 items-center gap-2 rounded-full px-3.5 text-sm font-semibold transition",
                  @ownership_scope == "personal" && "bg-white/10 text-white shadow-sm",
                  @ownership_scope != "personal" && "text-slate-400 hover:bg-white/[0.06] hover:text-white"
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
                  @ownership_scope == "household" && "bg-white/10 text-white shadow-sm",
                  @ownership_scope != "household" && "text-slate-400 hover:bg-white/[0.06] hover:text-white"
                ]}
              >
                <.icon name={if household_scope_available?(@households), do: "hero-home", else: "hero-plus"} class="h-4 w-4" />
                Household
              </button>
            </div>

            <.household_picker :if={@households != []} households={@households} selected_household_id={@selected_household_id} />
          </div>
        </div>
      </.glass>
    </section>
    """
  end

  def finance_dashboard_header(assigns) do
    ~H"""
    <section>
      <.glass class="px-6 py-6 sm:px-8" glow="linear-gradient(120deg, rgba(155,140,255,0.2), rgba(111,207,151,0.14))">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-[12px] font-semibold uppercase tracking-[0.24em] text-slate-400"><%= greeting_date() %> · this month</p>
            <h1 class="mt-1 text-xl font-display text-white"><%= greeting_headline(@current_scope.user) %></h1>
          </div>

          <div class="flex flex-wrap items-center gap-2.5">
            <div class="inline-flex items-center gap-1 rounded-full border border-white/10 bg-white/[0.04] px-1 py-1 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)]">
              <button
                type="button"
                phx-click="set_ownership_scope"
                phx-value-scope="personal"
                aria-label="Personal finance scope"
                title="Personal finance scope"
                class={[
                  "inline-flex h-9 items-center gap-2 rounded-full px-3.5 text-sm font-semibold transition",
                  @ownership_scope == "personal" && "bg-white/10 text-white shadow-sm",
                  @ownership_scope != "personal" && "text-slate-400 hover:bg-white/[0.06] hover:text-white"
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
                  @ownership_scope == "household" && "bg-white/10 text-white shadow-sm",
                  @ownership_scope != "household" && "text-slate-400 hover:bg-white/[0.06] hover:text-white"
                ]}
              >
                <.icon name={if household_scope_available?(@households), do: "hero-home", else: "hero-plus"} class="h-4 w-4" />
                Household
              </button>
            </div>

            <.household_picker :if={@households != []} households={@households} selected_household_id={@selected_household_id} />

            <button
              type="button"
              phx-click="open_focus_panel"
              phx-value-panel="transaction"
              aria-label="Add transaction"
              title="Add transaction"
              class="inline-flex h-10 items-center gap-1.5 rounded-xl border border-white/10 bg-white/[0.06] px-4 text-sm font-semibold text-slate-200 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)] transition hover:border-white/15 hover:bg-white/[0.04]"
            >
              <.icon name="hero-plus" class="h-4 w-4" /> Add transaction
            </button>
          </div>
        </div>

        <div class="mt-6 grid gap-5 xl:grid-cols-[minmax(0,1.1fr)_minmax(18rem,0.86fr)]">
          <div class="grid gap-3.5">
            <div class="grid gap-3.5 sm:grid-cols-2">
              <.metric_card
                label="Available cash"
                value={money_totals(@current_month_summary_totals.balance)}
                note="This month"
                tone="cash"
                icon="hero-banknotes"
                featured
              />
              <.metric_card
                label="Budget remaining"
                value={money_totals(@budget_remaining_totals)}
                note={budget_metric_note(@budget_statuses)}
                tone="budget"
                icon="hero-chart-bar-square"
              />
            </div>

            <div class="grid gap-3 sm:grid-cols-2">
              <.metric_card
                label="Income"
                value={money_totals(@current_month_summary_totals.income)}
                note="This month"
                tone="income"
                icon="hero-arrow-trending-up"
                compact
              />
              <.metric_card
                label="Expenses"
                value={money_totals(@current_month_summary_totals.expenses)}
                note="This month"
                tone="expense"
                icon="hero-arrow-trending-down"
                compact
              />
            </div>
          </div>

          <div class="rounded-[1.55rem] border border-white/10 bg-white/[0.04] p-5 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)] backdrop-blur-sm">
            <p class="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">This month's budget</p>

            <div class="mt-4 flex items-center justify-between gap-4">
              <div>
                <p class="text-xs text-slate-400">Spent</p>
                <p class="mt-1 text-lg font-mono font-semibold text-[var(--tone-expense)]"><%= money_totals(@budget_spent_totals) %></p>
              </div>
              <div class="text-right">
                <p class="text-xs text-slate-400">Remaining</p>
                <p class="mt-1 text-lg font-mono font-semibold text-[var(--tone-income)]"><%= money_totals(@budget_remaining_totals) %></p>
              </div>
            </div>

            <div class="mt-4 h-2 w-full overflow-hidden rounded-full bg-white/5">
              <div
                class={["h-full rounded-full", tone_class(overall_budget_tone(@budget_statuses), :bar)]}
                style={"width: #{budget_remaining_pct(@budget_usage_pct)}%"}
              >
              </div>
            </div>

            <p class="mt-2.5 text-[11px] text-slate-500">
              <%= if @budget_statuses == [],
                do: "No active budgets this month.",
                else: "#{round(@budget_usage_pct)}% of this month's budgets used." %>
            </p>
          </div>
        </div>
      </.glass>
    </section>
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
        @current == @scope && @bubble && "bg-[var(--tone-budget)] text-white shadow-[0_10px_20px_-16px_rgba(109,40,217,0.55)]",
        @current != @scope && @bubble && "text-slate-400 hover:bg-white/[0.04] hover:text-white",
        @current == @scope && !@bubble && "bg-white/10 text-white shadow-sm",
        @current != @scope && !@bubble && "text-slate-400 hover:bg-white/[0.06] hover:text-white"
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
        class="rounded-full border border-white/10 bg-white/[0.06] px-3.5 py-2 text-sm font-semibold text-slate-300 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)]"
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
      <div class="rounded-xl border border-white/10 bg-white/[0.04] p-5">
        <div>
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Households</p>
            <h3 class="mt-2 text-xl font-semibold tracking-tight text-white">Create or switch scope</h3>
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

      <div class="rounded-xl border border-white/10 bg-white/[0.06] p-5 shadow-sm">
        <div class="flex items-start justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Active scope</p>
            <h3 class="mt-2 text-xl font-semibold tracking-tight text-white">
              <%= selected_household_name(@selected_household) %>
            </h3>
          </div>
          <span class="rounded-full border border-white/10 bg-white/[0.04] px-3 py-1 text-xs font-semibold text-[var(--tone-budget)]">
            <%= household_role_label(@current_scope.user, @selected_household) %>
          </span>
        </div>

        <div class="mt-5 space-y-3">
          <div
            :for={member <- household_member_summaries(@selected_household)}
            class="flex items-center justify-between gap-3 rounded-xl border border-white/10 bg-white/[0.04] p-4"
          >
            <div>
              <p class="font-semibold text-white"><%= member.name %></p>
              <p class="mt-1 text-xs text-slate-400"><%= member.label %></p>
            </div>
            <span class="rounded-full border border-white/10 bg-white/[0.06] px-3 py-1 text-xs font-semibold text-slate-400">
              <%= member.role %>
            </span>
          </div>
          <div :if={@selected_household == nil} class="rounded-xl border border-dashed border-white/10 p-4 text-sm text-slate-400">
            Create a household to start shared tracking.
          </div>
        </div>

        <.form
          :if={household_owner?(@current_scope.user, @selected_household)}
          for={@member_form}
          phx-submit="add_household_member"
          class="mt-5 rounded-xl border border-white/10 bg-white/[0.04] p-4"
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

  def budget_overview_panel(assigns) do
    ~H"""
    <section class="rounded-2xl border border-white/10 bg-white/[0.06] p-5 shadow-sm backdrop-blur">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Budget overview</p>
          <h2 class="mt-2 text-2xl font-semibold tracking-tight text-white">Planned spending and event envelopes</h2>
        </div>
        <button type="button" phx-click="show_section" phx-value-section="budgets" class="btn btn-secondary btn-xs">
          Open budgets
        </button>
      </div>

      <div class="mt-5 grid gap-4 xl:grid-cols-[1.1fr_0.9fr]">
        <div class="space-y-3">
          <.budget_status_card :for={status <- Enum.take(@budget_statuses, 3)} status={status} />
          <div :if={@budget_statuses == []} class="rounded-xl border border-dashed border-white/10 bg-white/[0.04] p-4 text-sm text-slate-400">
            Create your first personal budget to start tracking daily, weekly, monthly, or yearly targets.
          </div>
        </div>

        <div class="rounded-xl border border-white/10 bg-white/[0.04] p-4">
          <div class="flex items-center justify-between gap-3">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Event budgets</p>
              <h3 class="mt-2 text-lg font-semibold text-white">Event budgets</h3>
            </div>
            <span class="rounded-full border border-white/10 bg-white/[0.06] px-3 py-1 text-xs font-semibold text-slate-400">
              <%= length(@event_budget_statuses) %> active
            </span>
          </div>

          <div class="mt-4 space-y-3">
            <div :for={status <- Enum.take(@event_budget_statuses, 3)} class="rounded-xl border border-white/10 bg-white/[0.06] p-4">
              <div class="flex items-start justify-between gap-3">
                <div>
                  <p class="font-semibold text-white"><%= status.budget.name %></p>
                  <p class="mt-1 text-xs text-slate-400">
                    <%= format_date(status.budget.start_date) %> to <%= format_date(status.budget.end_date) %>
                  </p>
                </div>
                <span class={["rounded-full px-2.5 py-1 text-xs font-semibold", tone_class(budget_state_tone(status), :soft)]}>
                  <%= budget_state_label(status) %>
                </span>
              </div>
              <div class="mt-4 h-2 overflow-hidden rounded-full bg-white/[0.04]">
                <div class={["h-full rounded-full", tone_class(budget_state_tone(status), :bar)]} style={"width: #{budget_remaining_pct(status.percentage)}%"} />
              </div>
              <div class="mt-3 flex items-center justify-between text-xs">
                <span class="text-slate-400">Spent <%= money(status.spent, status.budget.currency) %></span>
                <span class="font-semibold text-white">Remaining <%= money(status.remaining, status.budget.currency) %></span>
              </div>
            </div>

            <div :if={@event_budget_statuses == []} class="rounded-xl border border-dashed border-white/10 bg-white/[0.06] p-4 text-sm text-slate-400">
              Use a custom budget period for trips, repairs, or other one-off spending windows.
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  def signals_panel(assigns) do
    ~H"""
    <section class="rounded-2xl border border-white/10 bg-white/[0.06] p-5 shadow-sm backdrop-blur">
      <div class="flex flex-wrap items-start justify-between gap-4">
        <div>
          <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Signals</p>
          <h2 class="mt-2 text-2xl font-semibold tracking-tight text-white">Cash picture, visibility, and rules</h2>
        </div>
        <button type="button" phx-click="show_section" phx-value-section="insights" class="btn btn-secondary btn-xs">
          Insights
        </button>
      </div>

      <div class="mt-5 grid gap-3 sm:grid-cols-2">
        <div class="rounded-xl border border-white/10 bg-white/[0.04] p-4">
          <p class="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">Net flow</p>
          <p class={["mt-2 text-2xl font-semibold tracking-tight", tone_class("cash")]}>
            <%= money_totals(@period_summary_totals.balance) %>
          </p>
          <p class="mt-2 text-sm text-slate-400">Income minus expenses for <%= String.downcase(time_scope_title(@time_scope)) %>.</p>
        </div>
        <div class="rounded-xl border border-white/10 bg-white/[0.04] p-4">
          <p class="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">Tracked balances</p>
          <p class="mt-2 text-2xl font-semibold tracking-tight text-white">
            <%= money_totals(@account_total_balance_totals) %>
          </p>
          <p class="mt-2 text-sm leading-6 text-slate-400"><%= length(@accounts) %> tracked in this scope.</p>
        </div>
      </div>

      <div class="mt-5 grid gap-3 lg:grid-cols-[0.9fr_1.1fr]">
        <div class="space-y-3">
          <div :for={summary <- @account_summaries} class="flex items-center justify-between gap-4 rounded-xl border border-white/10 bg-white/[0.06] p-4">
            <div>
              <p class="font-semibold text-white"><%= summary.account.name %></p>
              <p class="mt-1 text-xs text-slate-400">
                <%= account_summary_subtitle(summary.account) %> · <%= summary.transaction_count %> linked transactions in view
              </p>
            </div>
            <div class="text-right">
              <p class="text-sm font-semibold text-white"><%= money(summary.account.current_balance, summary.account.currency) %></p>
              <p class="mt-1 text-xs text-slate-400"><%= signed_decimal(summary.net, summary.account.currency) %> net in range</p>
            </div>
          </div>

          <div :if={@account_summaries == []} class="rounded-xl border border-dashed border-white/10 bg-white/[0.04] p-4 text-sm text-slate-400">
            Add accounts to track balances and tie transactions to a real ledger source.
          </div>
        </div>

        <div class="space-y-3">
          <div :for={warning <- @health.warnings} class="rounded-xl border border-white/10 bg-[color-mix(in_srgb,var(--tone-review)_14%,transparent)] p-4 text-sm text-[var(--tone-review)]">
            <%= warning %>
          </div>
          <div :if={@health.warnings == []} class="rounded-xl border border-white/10 bg-[color-mix(in_srgb,var(--tone-income)_14%,transparent)] p-4 text-sm text-[var(--tone-income)]">
            No warnings in the current view.
          </div>
          <div class="rounded-xl border border-white/10 bg-white/[0.04] p-4 text-sm leading-6 text-slate-400">
            <p class="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Scope</p>
            <p class="mt-3">Personal data stays isolated per user. Household mode only shows shared household data.</p>
          </div>
        </div>
      </div>
    </section>
    """
  end

  def activity_panel(assigns) do
    ~H"""
    <section class="rounded-2xl border border-white/10 bg-white/[0.06] p-5 shadow-sm backdrop-blur">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Activity</p>
          <h2 class="mt-2 text-2xl font-semibold tracking-tight text-white">Recent movements and review queue</h2>
        </div>
        <div class="flex flex-wrap gap-2">
          <button type="button" phx-click="show_section" phx-value-section="transactions" class="btn btn-secondary btn-xs">
            Transactions
          </button>
          <button type="button" phx-click="show_section" phx-value-section="review" class="btn btn-secondary btn-xs">
            <%= review_section_label(@pending_review_count) %>
          </button>
        </div>
      </div>

      <div class="mt-5 space-y-3">
        <.transaction_row :for={transaction <- Enum.take(@transactions, 4)} transaction={transaction} compact />
        <div :if={@transactions == []} class="rounded-xl border border-dashed border-white/10 bg-white/[0.04] p-4 text-sm text-slate-400">
          No transactions recorded for this period.
        </div>
      </div>

      <div class="mt-5 rounded-xl border border-white/10 bg-white/[0.04] p-4">
        <div class="flex items-center justify-between gap-3">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Pending review</p>
            <h3 class="mt-2 text-lg font-semibold text-white">Imported suggestions</h3>
          </div>
          <span class="rounded-full border border-white/10 bg-white/[0.06] px-3 py-1 text-xs font-semibold text-slate-400">
            <%= @pending_review_count %> waiting
          </span>
        </div>

        <div class="mt-4 space-y-3">
          <.review_row :for={transaction <- Enum.take(@pending_transactions, 2)} transaction={transaction} compact />
          <div :if={@pending_transactions == []} class="rounded-xl border border-dashed border-white/10 bg-white/[0.06] p-4 text-sm text-slate-400">
            No personal transactions are waiting for review.
          </div>
        </div>
      </div>
    </section>
    """
  end

  def obligations_panel(assigns) do
    ~H"""
    <section class="rounded-2xl border border-white/10 bg-white/[0.06] p-5 shadow-sm backdrop-blur">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Obligations</p>
          <h2 class="mt-2 text-2xl font-semibold tracking-tight text-white">Debt commitments and payoff planning</h2>
        </div>
        <button type="button" phx-click="show_section" phx-value-section="debts" class="btn btn-secondary btn-xs">
          Open debts
        </button>
      </div>

      <div class="mt-5 grid gap-4 lg:grid-cols-[1fr_0.92fr]">
        <div class="space-y-3">
          <div :for={debt <- Enum.take(@debts, 4)} class="rounded-xl border border-white/10 bg-white/[0.04] p-4">
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="font-semibold text-white"><%= debt.name %></p>
                <p class="mt-1 text-xs text-slate-400">
                  <%= format_kind(debt.kind) %><%= if debt.provider, do: " with #{debt.provider}" %>
                </p>
              </div>
              <span class="text-sm font-semibold text-white"><%= money(debt.minimum_payment, debt.currency) %></span>
            </div>
            <div class="mt-3 flex flex-wrap items-center justify-between gap-2 text-xs">
              <span class="text-slate-400"><%= due_day_label(debt.due_day) %></span>
              <span class="font-semibold text-white">Balance <%= money(debt.current_balance, debt.currency) %></span>
            </div>
          </div>

          <div :if={@debts == []} class="rounded-xl border border-dashed border-white/10 bg-white/[0.04] p-4 text-sm text-slate-400">
            No active debts yet. Add one if you want repayment planning and obligations on the dashboard.
          </div>
        </div>

        <div class="rounded-xl border border-white/10 bg-white/[0.06] p-4">
          <p class="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Saved plans</p>
          <div class="mt-4 space-y-3">
            <div :for={plan <- Enum.take(@plans, 3)} class="rounded-xl border border-white/10 bg-white/[0.04] p-4">
              <div class="flex items-center justify-between gap-3">
                <p class="font-semibold text-white"><%= plan.name %></p>
                <span class="text-xs font-semibold text-slate-400"><%= format_date(plan.target_payoff_date) %></span>
              </div>
              <p class="mt-2 text-xs text-slate-400">
                <%= String.capitalize(plan.strategy) %> · <%= plan_money(plan.monthly_amount, @debt_currencies) %>
              </p>
            </div>

            <div :if={@plans == []} class="rounded-xl border border-dashed border-white/10 bg-white/[0.04] p-4 text-sm text-slate-400">
              Generate and save debt payoff plans to keep them visible here.
            </div>
          </div>
        </div>
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
        class="absolute inset-0 bg-slate-900/70 backdrop-blur-md"
        aria-label="Close detail panel"
      >
      </button>

      <div class="relative z-10 w-full max-w-5xl overflow-hidden rounded-2xl border border-white/10 bg-white/[0.06] shadow-2xl backdrop-blur-xl">
        <div class="flex items-center justify-between gap-4 border-b border-white/10 px-5 py-4 sm:px-6">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Detail panel</p>
            <h3 class="mt-2 text-2xl font-semibold tracking-tight text-white">
              <%= focus_panel_title(@panel) %>
            </h3>
          </div>
          <button type="button" phx-click="close_focus_panel" class="btn btn-ghost btn-xs">
            <.icon name="hero-x-mark" class="h-4 w-4" />
          </button>
        </div>

        <div class="max-h-[80vh] overflow-y-auto bg-white/[0.05] p-5 sm:p-6">
          <.household_panel :if={@panel == "household"} {assigns} />
          <.transaction_panel :if={@panel == "transaction"} {assigns} />
          <.budget_panel :if={@panel == "budget"} {assigns} />
          <.debt_panel :if={@panel == "debt"} {assigns} />
          <.budget_overview_panel :if={@panel == "budget_overview"} {assigns} />
          <.activity_panel :if={@panel == "activity"} {assigns} />
          <.signals_panel :if={@panel == "signals"} {assigns} />
          <.obligations_panel :if={@panel == "obligations"} {assigns} />
        </div>
      </div>
    </div>
    """
  end

  def accounts_panel(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
      <div class="rounded-2xl border border-white/10 bg-white/[0.06] p-5 shadow-sm">
        <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Account setup</p>
        <h2 class="mt-2 text-2xl font-semibold tracking-tight text-white">Track balances by scope</h2>

        <.form for={@account_form} phx-submit="create_account" class="mt-5 space-y-4">
          <div class="grid gap-3 sm:grid-cols-2">
            <.finance_input form={@account_form} field={:name} label="Account name" placeholder="Main checking" />
            <.finance_input form={@account_form} field={:institution} label="Institution" placeholder="Popular Bank" />
            <.finance_select form={@account_form} field={:kind} label="Kind" options={account_kind_options()} />
            <.finance_select form={@account_form} field={:currency} label="Currency" options={currency_options()} />
            <.finance_input form={@account_form} field={:current_balance} label="Current balance" type="number" step="0.01" placeholder="2400.00" />
            <.finance_input form={@account_form} field={:available_balance} label="Available balance" type="number" step="0.01" placeholder="2200.00" />
          </div>

          <.finance_input form={@account_form} field={:notes} label="Notes" placeholder="Optional note" />

          <div class="flex justify-end">
            <button type="submit" class="btn btn-primary btn-sm">Save account</button>
          </div>
        </.form>
      </div>

      <div class="rounded-2xl border border-white/10 bg-white/[0.06] p-5 shadow-sm">
        <div class="flex items-start justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Tracked accounts</p>
            <h2 class="mt-2 text-2xl font-semibold tracking-tight text-white">Scope balances and activity</h2>
          </div>
          <span class="rounded-full border border-white/10 bg-white/[0.04] px-3 py-1 text-xs font-semibold text-[var(--tone-budget)]">
            <%= money_totals(@account_total_balance_totals) %>
          </span>
        </div>

        <div class="mt-5 space-y-3">
          <div :for={summary <- @account_summaries} class="rounded-xl border border-white/10 bg-white/[0.04] p-4">
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="font-semibold text-white"><%= summary.account.name %></p>
                <p class="mt-1 text-xs text-slate-400"><%= account_summary_subtitle(summary.account) %></p>
              </div>
              <div class="text-right">
                <p class="font-semibold text-white"><%= money(summary.account.current_balance, summary.account.currency) %></p>
                <p class="mt-1 text-xs text-slate-400"><%= signed_decimal(summary.net, summary.account.currency) %> this range</p>
              </div>
            </div>

            <div class="mt-3 grid gap-2 text-sm text-slate-400 sm:grid-cols-3">
              <.status_row label="Income" value={money(summary.income, summary.account.currency)} />
              <.status_row label="Expenses" value={money(summary.expenses, summary.account.currency)} />
              <.status_row label="Linked tx" value={Integer.to_string(summary.transaction_count)} />
            </div>
          </div>

          <div :if={@account_summaries == []} class="rounded-xl border border-dashed border-white/10 p-4 text-sm text-slate-400">
            No accounts yet for this scope.
          </div>
        </div>
      </div>
    </section>
    """
  end

  def transaction_panel(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[0.82fr_1.18fr]">
      <div class="rounded-2xl border border-white/10 bg-white/[0.06] p-5 shadow-sm">
        <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Manual capture</p>
        <h2 class="mt-2 text-2xl font-semibold tracking-tight text-white"><%= transaction_form_title(@editing_transaction_id) %></h2>

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

      <div class="rounded-2xl border border-white/10 bg-white/[0.06] p-5 shadow-sm">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Ledger</p>
            <h2 class="mt-2 text-2xl font-semibold tracking-tight text-white">Recent transactions</h2>
          </div>
          <span class="text-xs font-semibold text-slate-400"><%= length(@transactions) %> shown</span>
        </div>

        <div class="mt-5 space-y-3">
          <.transaction_row :for={transaction <- Enum.take(@transactions, 6)} transaction={transaction} compact />
          <div :if={@transactions == []} class="rounded-xl border border-dashed border-white/10 p-4 text-sm text-slate-400">
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
        <div class="rounded-2xl border border-white/10 bg-white/[0.06] p-5 shadow-sm">
          <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Spending plan</p>
          <h2 class="mt-2 text-2xl font-semibold tracking-tight text-white">Create budget</h2>

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

        <div class="rounded-2xl border border-white/10 bg-white/[0.06] p-5 shadow-sm">
          <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Categories</p>
          <h2 class="mt-2 text-2xl font-semibold tracking-tight text-white">Add category</h2>

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

      <div class="rounded-2xl border border-white/10 bg-white/[0.06] p-5 shadow-sm">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Active budgets</p>
            <h2 class="mt-2 text-2xl font-semibold tracking-tight text-white">Budget status</h2>
          </div>
          <span class="text-xs font-semibold text-slate-400"><%= money_totals(@budget_remaining_totals) %> remaining</span>
        </div>

        <div class="mt-5 space-y-3">
          <.budget_status_card :for={status <- @budget_statuses} status={status} />
          <div :if={@budget_statuses == []} class="rounded-xl border border-dashed border-white/10 p-4 text-sm text-slate-400">
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
      <div class="rounded-2xl border border-white/10 bg-white/[0.06] p-5 shadow-sm">
        <div>
          <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Debt setup</p>
          <h2 class="mt-2 text-2xl font-semibold tracking-tight text-white">Add debt</h2>
        </div>

        <.form for={@debt_form} phx-submit="create_debt" class="mt-5 rounded-xl border border-white/10 bg-white/[0.04] p-4">
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
          <div :if={@debts == []} class="rounded-xl border border-dashed border-white/10 p-4 text-sm text-slate-400">
            Add debts to compare payoff strategies.
          </div>

          <.debt_card :for={debt <- @debts} debt={debt} payment_form={@payment_form} payment_form_debt_id={@payment_form_debt_id} />
        </div>
      </div>

      <div class="rounded-2xl border border-white/10 bg-white/[0.06] p-5 shadow-sm">
        <div class="flex flex-wrap items-center justify-between gap-4">
              <div>
                <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Payoff comparison</p>
                <h2 class="mt-2 text-2xl font-semibold tracking-tight text-white">Snowball vs avalanche</h2>
              </div>
          <button type="button" phx-click="generate_plans" class="btn btn-primary btn-xs">Refresh</button>
        </div>

        <div class="mt-5 grid gap-4 lg:grid-cols-2">
          <.plan_card :for={plan <- @comparison} plan={plan} debt_currencies={@debt_currencies} />
          <div :if={@comparison == []} class="rounded-lg border border-dashed border-white/10 p-4 text-sm text-slate-400 lg:col-span-2">
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
      <div class="rounded-2xl border border-white/10 bg-white/[0.06] p-5 shadow-sm">
        <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Savings goals</p>
        <h2 class="mt-2 text-2xl font-semibold tracking-tight text-white">Create goal</h2>

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

      <div class="rounded-2xl border border-white/10 bg-white/[0.06] p-5 shadow-sm">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Progress</p>
            <h2 class="mt-2 text-2xl font-semibold tracking-tight text-white">Active goals</h2>
          </div>
          <span class="rounded-full border border-white/10 bg-white/[0.04] px-3 py-1 text-xs font-semibold text-[var(--tone-budget)]">
            <%= length(@savings_goals) %> tracked
          </span>
        </div>

        <div class="mt-5 space-y-3">
          <.savings_goal_card :for={goal <- @savings_goals} goal={goal} />
          <div :if={@savings_goals == []} class="rounded-xl border border-dashed border-white/10 p-4 text-sm text-slate-400">
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
    <div class="rounded-lg border border-white/10 bg-white/[0.06] p-4">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p class="font-semibold text-white"><%= @goal.name %></p>
          <p class="mt-1 text-xs text-slate-400">
            <%= if @goal.target_date, do: "Target #{format_date(@goal.target_date)}", else: "No target date" %>
          </p>
        </div>
        <span class={["rounded-full px-2.5 py-1 text-xs font-semibold", tone_class(savings_goal_tone(@goal), :soft)]}>
          <%= savings_goal_state_label(@goal) %>
        </span>
      </div>

      <div class="mt-4 h-2 overflow-hidden rounded-full bg-white/[0.04]">
        <div class={["h-full rounded-full", tone_class(savings_goal_tone(@goal), :bar)]} style={"width: #{min(@pct, 100)}%"} />
      </div>

      <div class="mt-3 grid grid-cols-3 gap-2 text-xs">
        <div>
          <p class="text-slate-400">Saved</p>
          <p class="mt-1 font-semibold text-white"><%= money(@goal.saved_amount, @goal.currency) %></p>
        </div>
        <div>
          <p class="text-slate-400">Target</p>
          <p class="mt-1 font-semibold text-white"><%= money(@goal.target_amount, @goal.currency) %></p>
        </div>
        <div>
          <p class="text-slate-400">Progress</p>
          <p class="mt-1 font-semibold text-white"><%= Float.round(@pct, 1) %>%</p>
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
        <span class="truncate font-medium text-white"><%= @goal.name %></span>
        <span class="font-mono text-[12px] text-slate-400"><%= @pct |> min(100) |> trunc() %>%</span>
      </div>
      <div class="mt-2.5 h-1.5 overflow-hidden rounded-full bg-white/10">
        <div class={["h-full rounded-full", tone_class(savings_goal_tone(@goal), :bar)]} style={"width: #{min(@pct, 100)}%"} />
      </div>
    </div>
    """
  end

  def overview_section(assigns) do
    ~H"""
    <section class="relative overflow-hidden rounded-[2.45rem] border border-white/10 bg-white/[0.03] p-5 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)] sm:p-6 xl:p-7">
      <div class="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(155,140,255,0.12),transparent_34%),radial-gradient(circle_at_bottom_right,rgba(111,207,151,0.1),transparent_30%)]" />

      <div class="relative grid gap-5 xl:grid-cols-[minmax(0,1.2fr)_minmax(18rem,0.8fr)]">
        <.overview_glass_pane>
          <div class="flex flex-wrap items-start justify-between gap-4">
            <div>
              <p class="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-400">Flow</p>
              <h2 class="mt-2 text-[1.65rem] font-semibold tracking-tight text-white">Income vs. spending</h2>
            </div>

            <div class="flex flex-wrap items-center justify-end gap-2">
              <span class="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.06] px-3 py-1.5 text-xs font-medium text-slate-400 backdrop-blur-sm">
                <span class="inline-flex h-5 min-w-5 items-center justify-center rounded-full bg-white/10 px-1 text-[11px] font-semibold text-[var(--tone-budget)]">
                  <%= length(@accounts) %>
                </span>
                Accounts
              </span>
              <span class="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.06] px-3 py-1.5 text-xs font-medium text-slate-400 backdrop-blur-sm">
                <.icon name="hero-banknotes" class="h-3.5 w-3.5 text-[var(--tone-income)]" />
                <%= money_totals(@current_month_summary_totals.balance) %>
              </span>
              <div class="flex items-center gap-4 text-[11px] text-slate-400">
                <span class="flex items-center gap-1.5"><span class="inline-block h-2.5 w-2.5 rounded-full bg-[var(--tone-income)]"></span>Income</span>
                <span class="flex items-center gap-1.5"><span class="inline-block h-2.5 w-2.5 rounded-full bg-[var(--tone-expense)]"></span>Spending</span>
              </div>
            </div>
          </div>

          <div class="mt-5 grid gap-4 lg:grid-cols-[minmax(0,1.12fr)_0.88fr]">
            <div class="rounded-[1.55rem] border border-white/10 bg-white/[0.04] p-5 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)] backdrop-blur-sm">
              <div class="flex flex-wrap items-center justify-between gap-3">
                <p class="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">Cashflow · last 6 months</p>
                <div class="flex items-center gap-3 text-[11px] text-slate-400">
                  <span class="flex items-center gap-1.5">
                    <span class="inline-block h-2.5 w-2.5 rounded-full bg-[var(--tone-income)]"></span>Net positive
                  </span>
                  <span class="flex items-center gap-1.5">
                    <span class="inline-block h-2.5 w-2.5 rounded-full bg-[var(--tone-expense)]"></span>Net negative
                  </span>
                </div>
              </div>
              <div class="mt-6 flex h-[15rem] items-center justify-center">
                <.cashflow_grid months={@cashflow_months} />
              </div>
            </div>

            <div class="grid gap-4">
              <div class="rounded-[1.55rem] border border-white/10 bg-white/[0.04] p-5 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)] backdrop-blur-sm">
                <p class="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">Scope balance</p>
                <p class="mt-4 text-[2.3rem] font-semibold tracking-tight text-white"><%= money_totals(@account_total_balance_totals) %></p>
                <p class={["mt-3 text-sm font-medium", Decimal.compare(@period_summary.balance, Decimal.new("0")) == :lt && "text-[var(--tone-expense)]", Decimal.compare(@period_summary.balance, Decimal.new("0")) != :lt && "text-[var(--tone-income)]"]}>
                  <%= signed_money_totals(@period_summary_totals.balance) %> in <%= String.downcase(time_scope_title(@time_scope)) %> view
                </p>
              </div>

              <div class="grid gap-3 sm:grid-cols-2">
                <button
                  type="button"
                  phx-click="open_focus_panel"
                  phx-value-panel="accounts"
                  class="flex min-h-[6.4rem] flex-col justify-between rounded-[1.45rem] border border-white/10 bg-white/[0.04] p-4 text-left shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)] backdrop-blur-sm transition hover:bg-white/[0.08]"
                >
                  <span class="inline-flex h-8 w-8 items-center justify-center rounded-full bg-white/10 text-[var(--tone-budget)]">
                    <.icon name="hero-building-library" class="h-4 w-4" />
                  </span>
                  <div>
                    <p class="font-semibold text-white">Accounts</p>
                    <p class="mt-1 text-xs text-slate-400"><%= money_totals(@account_total_balance_totals) %></p>
                  </div>
                </button>

                <button
                  type="button"
                  phx-click="show_section"
                  phx-value-section="review"
                  class="flex min-h-[6.4rem] flex-col justify-between rounded-[1.45rem] border border-white/10 bg-white/[0.04] p-4 text-left shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)] backdrop-blur-sm transition hover:bg-white/[0.08]"
                >
                  <span class="inline-flex h-8 w-8 items-center justify-center rounded-full bg-[color-mix(in_srgb,var(--tone-review)_16%,transparent)] text-[var(--tone-review)]">
                    <.icon name="hero-shield-check" class="h-4 w-4" />
                  </span>
                  <div>
                    <p class="font-semibold text-white">Review</p>
                    <p class="mt-1 text-xs text-slate-400"><%= pending_review_note(@pending_review_count) %></p>
                  </div>
                </button>
              </div>
            </div>
          </div>
        </.overview_glass_pane>

        <.overview_glass_pane>
          <div class="flex items-center justify-between gap-4">
            <div>
              <p class="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-400">Activity</p>
              <h2 class="mt-2 text-xl font-semibold tracking-tight text-white">Recent transactions</h2>
            </div>
            <button type="button" phx-click="show_section" phx-value-section="transactions" class="text-[11px] font-semibold uppercase tracking-[0.16em] text-slate-400 transition hover:text-slate-300">
              View all
            </button>
          </div>

          <div class="mt-5 space-y-2.5">
            <div :for={transaction <- @recent_transactions} class="flex items-center gap-3 rounded-[1.12rem] border border-white/10 bg-white/[0.06] px-4 py-3.5 backdrop-blur-sm">
              <span class={["inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-xl", tone_class(transaction.type, :soft)]}>
                <.icon
                  name={if transaction.type == "income", do: "hero-arrow-trending-up", else: "hero-arrow-trending-down"}
                  class="h-4 w-4"
                />
              </span>
              <div class="min-w-0 flex-1">
                <p class="truncate font-medium text-white"><%= transaction.description || review_title(transaction) %></p>
                <div class="mt-1 flex flex-wrap items-center gap-2 text-[11px] text-slate-400">
                  <span><%= format_date(transaction.transaction_date) %></span>
                  <span :if={transaction.account} class="rounded-full bg-white/[0.04] px-2 py-1"><%= transaction.account.name %></span>
                </div>
              </div>
              <p class={["shrink-0 pt-0.5 font-mono text-sm font-semibold", tone_class(transaction.type)]}>
                <%= signed_money(transaction) %>
              </p>
            </div>

            <div :if={@recent_transactions == []} class="rounded-[1.1rem] border border-dashed border-white/10 bg-white/[0.06] px-4 py-5 text-sm text-slate-400 backdrop-blur-sm">
              No transactions yet.
            </div>
          </div>
        </.overview_glass_pane>

        <.overview_glass_pane class="xl:col-span-2">
          <div class="flex flex-wrap items-center justify-between gap-4">
            <div>
              <p class="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-400">Spending</p>
              <h2 class="mt-2 text-lg font-semibold text-white">By category · this month</h2>
            </div>
            <button type="button" phx-click="show_section" phx-value-section="budgets" class="text-[11px] font-semibold uppercase tracking-[0.16em] text-slate-400 transition hover:text-slate-300">
              Open budgets
            </button>
          </div>

          <div class="mt-5">
            <.spending_breakdown_card breakdown={@spending_breakdown} />
          </div>
        </.overview_glass_pane>

        <.overview_glass_pane class="xl:col-span-2">
          <div class="grid gap-4 xl:grid-cols-2">
            <div class="rounded-[1.55rem] border border-white/10 bg-white/[0.06] p-5 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)] backdrop-blur-sm">
              <div class="flex items-center justify-between gap-3">
                <div>
                  <p class="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-400">Review</p>
                  <h2 class="mt-2 text-lg font-semibold text-white">Pending queue</h2>
                </div>
                <button type="button" phx-click="show_section" phx-value-section="review" class="text-[11px] font-semibold uppercase tracking-[0.16em] text-slate-400 transition hover:text-slate-300">
                  Open review queue
                </button>
              </div>

              <div class="mt-5 space-y-2.5">
                <div :for={transaction <- Enum.take(@pending_transactions, 3)} class="rounded-[1.05rem] border border-white/10 bg-white/[0.06] p-3.5 backdrop-blur-sm">
                  <div class="flex items-start justify-between gap-3">
                    <div class="min-w-0">
                      <p class="truncate font-medium text-white"><%= review_title(transaction) %></p>
                      <p class="mt-1 text-xs text-slate-400"><%= format_date(transaction.transaction_date) %></p>
                    </div>
                    <span class="rounded-full bg-[color-mix(in_srgb,var(--tone-review)_16%,transparent)] px-2 py-1 text-[11px] font-semibold text-[var(--tone-review)]">Review</span>
                  </div>
                </div>

                <div :if={@pending_transactions == []} class="rounded-[1rem] border border-dashed border-white/10 bg-white/[0.06] px-4 py-4 text-sm text-slate-400 backdrop-blur-sm">
                  Queue clear.
                </div>
              </div>
            </div>

            <div class="rounded-[1.55rem] border border-white/10 bg-white/[0.06] p-5 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)] backdrop-blur-sm">
              <div class="flex items-center justify-between gap-3">
                <div>
                  <p class="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-400">Obligations</p>
                  <h2 class="mt-2 text-lg font-semibold text-white">Debts</h2>
                </div>
                <button type="button" phx-click="show_section" phx-value-section="debts" class="text-[11px] font-semibold uppercase tracking-[0.16em] text-slate-400 transition hover:text-slate-300">
                  Details
                </button>
              </div>

              <div class="mt-5 space-y-2.5">
                <div :for={debt <- Enum.take(@debts, 3)} class="rounded-[1.05rem] border border-white/10 bg-white/[0.06] px-4 py-3.5 backdrop-blur-sm">
                  <div class="flex items-start justify-between gap-4">
                    <div>
                      <p class="font-medium text-white"><%= debt.name %></p>
                      <p class="mt-1 text-xs text-slate-400"><%= due_day_label(debt.due_day) %></p>
                    </div>
                    <div class="text-right">
                      <p class="font-mono text-sm font-semibold text-white"><%= money(debt.current_balance, debt.currency) %></p>
                      <p class="mt-1 text-xs text-slate-400"><%= money(debt.minimum_payment, debt.currency) %> min</p>
                    </div>
                  </div>
                </div>

                <div :if={@debts == []} class="rounded-[1rem] border border-dashed border-white/10 bg-white/[0.06] px-4 py-4 text-sm text-slate-400 backdrop-blur-sm">
                  No debts tracked.
                </div>
              </div>
            </div>
          </div>
        </.overview_glass_pane>
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

    ~H"""
    <section>
      <.glass glow="linear-gradient(120deg, rgba(155,140,255,0.32), rgba(111,207,151,0.22))" class="p-6 sm:p-7 xl:p-8">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p class="text-[11px] font-semibold uppercase tracking-[0.24em] text-slate-400">Patrimonio neto</p>
            <h2 class="mt-2 text-[1.65rem] font-semibold tracking-tight text-white">Net worth</h2>
            <p class="mt-1 max-w-xl text-sm leading-6 text-slate-400">
              Everything you own minus everything you owe, pulled live from your tracked accounts and debts.
            </p>
          </div>
          <span class="rounded-full border border-white/10 bg-white/[0.06] px-3 py-1.5 text-xs font-medium text-slate-400 backdrop-blur-sm">
            <%= length(@net_worth_items) %> tracked items
          </span>
        </div>

        <div class="mt-6 grid gap-4 sm:grid-cols-3">
          <div class="rounded-[1.55rem] border border-white/10 bg-white/[0.06] p-5 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)] backdrop-blur-sm">
            <p class="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">Net worth</p>
            <p class="mt-3 font-display text-3xl tracking-tight text-white tabular-nums"><%= money_totals(@net_worth_summary.net) %></p>
          </div>
          <div class="rounded-[1.55rem] border border-white/10 bg-white/[0.04] p-5 backdrop-blur-sm">
            <p class="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">Assets</p>
            <p class="mt-3 text-xl font-mono font-semibold text-[var(--tone-income)]"><%= money_totals(@net_worth_summary.assets) %></p>
          </div>
          <div class="rounded-[1.55rem] border border-white/10 bg-white/[0.04] p-5 backdrop-blur-sm">
            <p class="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">Liabilities</p>
            <p class="mt-3 text-xl font-mono font-semibold text-[var(--tone-expense)]"><%= money_totals(@net_worth_summary.liabilities) %></p>
          </div>
        </div>

        <div :if={@net_worth_allocation != []} class="mt-6 space-y-4">
          <div :for={row <- @net_worth_allocation} :if={Decimal.compare(row.total, Decimal.new("0")) != :eq}>
            <p class="mb-1.5 text-[11px] font-semibold uppercase tracking-[0.16em] text-slate-400"><%= row.currency %> allocation</p>
            <div class="flex h-2.5 w-full overflow-hidden rounded-full bg-white/5">
              <div
                :for={segment <- row.segments}
                :if={segment.pct > 0}
                class={tone_class(segment.tone, :bar)}
                style={"width: #{Float.round(segment.pct, 1)}%"}
                title={networth_category_meta(segment.key).label}
              >
              </div>
            </div>
          </div>
        </div>

        <div class="mt-7 flex flex-wrap items-center justify-between gap-3">
          <h3 class="text-sm font-semibold text-white">Accounts &amp; debts</h3>
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

        <div class="mt-3 divide-y divide-white/5">
          <.net_worth_row
            :for={item <- @visible_net_worth_items}
            item={item}
            meta={networth_category_meta(item.category)}
            max_amount={@net_worth_max_amount}
          />
          <div :if={@visible_net_worth_items == []} class="rounded-xl border border-dashed border-white/10 bg-white/[0.04] p-4 text-sm text-slate-400">
            <%= if @net_worth_items == [],
              do: "Add an account or a debt to see your net worth here.",
              else: "No items in this category yet." %>
          </div>
        </div>
      </.glass>
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
        @active && "border-white/10 bg-white/10 text-white shadow-sm",
        !@active && "border-white/10 bg-white/[0.03] text-slate-400 hover:bg-white/[0.06] hover:text-white"
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
        <p class="truncate text-sm font-medium text-white"><%= @item.name %></p>
        <p class="text-xs text-slate-400"><%= @item.subtitle %> · <%= @meta.label %></p>
      </div>
      <div class="hidden w-28 md:block">
        <div class="h-1.5 w-full overflow-hidden rounded-full bg-white/5">
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
        Decimal.compare(@item.amount, Decimal.new("0")) != :lt && "text-white"
      ]}>
        <%= money(@item.amount, @item.currency) %>
      </p>
    </div>
    """
  end

  def transactions_section(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[0.72fr_1.28fr]">
      <div class="rounded-[1.75rem] border border-white/10 bg-white/[0.06] p-5 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)] backdrop-blur sm:p-6">
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Capture</p>
        <h2 class="mt-1 text-xl font-semibold text-white">Transactions</h2>
        <div class="mt-5">
          <button type="button" phx-click="open_focus_panel" phx-value-panel="transaction" class="btn btn-primary btn-sm">
            + Add transaction
          </button>
        </div>
      </div>

      <div class="rounded-[1.75rem] border border-white/10 bg-white/[0.06] p-5 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)] backdrop-blur sm:p-6">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Ledger · <%= @date_window_label %></p>
            <h2 class="mt-1 text-xl font-semibold text-white">Recent transactions</h2>
          </div>
          <div class="flex flex-wrap items-center gap-2.5">
            <div class="inline-flex flex-wrap items-center gap-1 rounded-full border border-white/10 bg-white/[0.06] px-1.5 py-1.5 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)]">
              <.time_scope_button current={@time_scope} scope="day" bubble />
              <.time_scope_button current={@time_scope} scope="week" bubble />
              <.time_scope_button current={@time_scope} scope="month" bubble />
              <.time_scope_button current={@time_scope} scope="year" bubble />
            </div>
            <span class="text-xs font-semibold text-slate-400"><%= length(@transactions) %> shown</span>
          </div>
        </div>

        <div class="mt-4 space-y-3">
          <.transaction_row :for={transaction <- @transactions} transaction={transaction} />
          <div :if={@transactions == []} class="rounded-xl border border-dashed border-white/10 bg-white/[0.04] p-4 text-sm text-slate-400">
            Add income and expenses to start tracking cash flow.
          </div>
        </div>
      </div>
    </section>
    """
  end

  def review_section(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[1.1fr_0.9fr]">
      <div class="rounded-[1.75rem] border border-white/10 bg-white/[0.06] p-5 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)] backdrop-blur sm:p-6">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Pending review</p>
            <h2 class="mt-1 text-xl font-semibold text-white">Imported transaction suggestions</h2>
          </div>
          <span class="text-xs font-semibold text-slate-400"><%= @pending_review_count %> waiting</span>
        </div>

        <div class="mt-4 space-y-3">
          <.review_row :for={transaction <- @pending_transactions} transaction={transaction} />
          <div :if={@pending_transactions == []} class="rounded-xl border border-dashed border-white/10 bg-white/[0.04] p-4 text-sm text-slate-400">
            No pending items right now.
          </div>
        </div>
      </div>

      <div class="rounded-[1.75rem] border border-white/10 bg-white/[0.06] p-5 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)] backdrop-blur sm:p-6">
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Review cadence</p>
        <h2 class="mt-1 text-xl font-semibold text-white">What happens here</h2>
        <div class="mt-5 space-y-3 text-sm leading-6 text-slate-400">
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
      <div class="rounded-[1.75rem] border border-white/10 bg-white/[0.06] p-5 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)] backdrop-blur sm:p-6">
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Planning</p>
        <h2 class="mt-1 text-xl font-semibold text-white">Budgets</h2>
        <div class="mt-5">
          <button type="button" phx-click="open_focus_panel" phx-value-panel="budget" class="btn btn-primary btn-sm">
            + Budget
          </button>
        </div>
      </div>

      <div class="rounded-[1.75rem] border border-white/10 bg-white/[0.06] p-5 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)] backdrop-blur sm:p-6">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Active budgets</p>
            <h2 class="mt-1 text-xl font-semibold text-white">Budget status</h2>
          </div>
          <div class="flex flex-wrap items-center gap-2">
            <span class="inline-flex items-center rounded-full border border-white/10 bg-white/[0.04] px-3 py-1 text-[11px] font-medium text-slate-400">
              <%= current_month_range_label() %>
            </span>
            <span class="text-xs font-semibold text-slate-400"><%= money_totals(@budget_remaining_totals) %> remaining</span>
          </div>
        </div>
        <p class="mt-1.5 text-[11px] text-slate-500">Each budget tracks its own period — this shows the current calendar month for reference.</p>

        <div class="mt-4 space-y-3">
          <.budget_status_card :for={status <- @budget_statuses} status={status} />
          <div :if={@budget_statuses == []} class="rounded-xl border border-dashed border-white/10 bg-white/[0.04] p-4 text-sm text-slate-400">
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
      <div class="rounded-[1.75rem] border border-white/10 bg-white/[0.06] p-5 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)] backdrop-blur sm:p-6">
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Obligations</p>
        <h2 class="mt-1 text-xl font-semibold text-white">Debts</h2>
        <div class="mt-5">
          <button type="button" phx-click="open_focus_panel" phx-value-panel="debt" class="btn btn-primary btn-sm">
            + Debt
          </button>
        </div>

        <div class="mt-5 space-y-3">
          <div :if={@debts == []} class="rounded-xl border border-dashed border-white/10 bg-white/[0.04] p-4 text-sm text-slate-400">
            Add debts to compare payoff strategies.
          </div>

          <.debt_card :for={debt <- @debts} debt={debt} payment_form={@payment_form} payment_form_debt_id={@payment_form_debt_id} />
        </div>
      </div>

      <div class="rounded-[1.75rem] border border-white/10 bg-white/[0.06] p-5 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)] backdrop-blur sm:p-6">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Payoff comparison</p>
            <h2 class="mt-1 text-xl font-semibold text-white">Snowball vs avalanche</h2>
          </div>
          <button type="button" phx-click="generate_plans" class="btn btn-primary btn-xs">Refresh</button>
        </div>

        <div class="mt-5 grid gap-4 lg:grid-cols-2">
          <.plan_card :for={plan <- @comparison} plan={plan} debt_currencies={@debt_currencies} />
          <div :if={@comparison == []} class="rounded-xl border border-dashed border-white/10 bg-white/[0.04] p-4 text-sm text-slate-400 lg:col-span-2">
            Generate plans to compare payoff order, payoff month, and estimated interest.
          </div>
        </div>

        <div class="mt-6">
          <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Saved plans</p>
          <div class="mt-3 space-y-2">
            <div :if={@plans == []} class="rounded-xl border border-white/10 bg-white/[0.04] p-4 text-sm text-slate-400">
              No saved payoff plans yet.
            </div>
            <div :for={plan <- @plans} class="flex items-center justify-between gap-4 rounded-xl border border-white/10 bg-white/[0.06] p-4">
              <div>
                <p class="font-semibold text-white"><%= plan.name %></p>
                <p class="mt-1 text-xs text-slate-400">
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
      <div class="rounded-[1.75rem] border border-white/10 bg-white/[0.06] p-5 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)] backdrop-blur sm:p-6">
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Signals</p>
        <h2 class="mt-1 text-xl font-semibold text-white">Financial health</h2>

        <div class="mt-5 space-y-3">
          <.status_row label="Debt-to-income" value={"#{@health.debt_to_income_ratio}%"} />
          <.status_row label="Minimum payment burden" value={"#{@health.minimum_payment_burden}%"} />
          <.status_row label="Monthly debt minimums" value={money_totals(@minimum_debt_payment_totals)} />
          <.status_row label="Current free cash flow" value={money_totals(@current_month_summary_totals.balance)} />
        </div>
      </div>

      <div class="rounded-[1.75rem] border border-white/10 bg-white/[0.06] p-5 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)] backdrop-blur sm:p-6">
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Reading guide</p>
        <h2 class="mt-1 text-xl font-semibold text-white">How to read this snapshot</h2>
        <div class="mt-5 space-y-3 text-sm leading-6 text-slate-400">
          <p>Health metrics reflect confirmed transactions in the active scope.</p>
          <p>Warnings call out pressure points worth reviewing before they become problems.</p>
        </div>
      </div>

      <div class="rounded-[1.75rem] border border-white/10 bg-white/[0.06] p-5 shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)] backdrop-blur sm:p-6 lg:col-span-2">
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Warnings</p>
        <div class="mt-4 space-y-2">
          <div :for={warning <- @health.warnings} class="rounded-lg border border-white/10 bg-[color-mix(in_srgb,var(--tone-review)_14%,transparent)] p-3 text-sm text-[var(--tone-review)]">
            <%= warning %>
          </div>
          <div :if={@health.warnings == []} class="rounded-lg border border-white/10 bg-[color-mix(in_srgb,var(--tone-income)_14%,transparent)] p-3 text-sm text-[var(--tone-income)]">
            No warnings in the current snapshot.
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :tone, :string, default: "cash"
  attr :note, :any, default: nil
  attr :featured, :boolean, default: false
  attr :compact, :boolean, default: false
  attr :icon, :string, default: nil

  def metric_card(assigns) do
    ~H"""
    <div
      class={[
        "rounded-[1.15rem] border transition duration-200 hover:-translate-y-0.5",
        @compact && "p-3",
        !@compact && "p-4",
        @featured && "border-white/15 bg-[linear-gradient(160deg,rgba(155,140,255,0.9)_0%,rgba(124,58,237,0.82)_48%,rgba(111,207,151,0.5)_100%)] text-white shadow-[0_18px_40px_-26px_rgba(109,40,217,0.34)]",
        !@featured && "border-white/10 bg-white/[0.04] shadow-[0_20px_40px_-24px_rgba(0,0,0,0.55)]"
      ]}
    >
      <div class="flex items-start justify-between gap-2">
        <p class={["text-[10px] font-semibold uppercase tracking-[0.2em]", @featured && "text-white/55", !@featured && "text-slate-400"]}>
          <%= @label %>
        </p>
        <span
          :if={@icon}
          class={[
            "inline-flex h-7 w-7 shrink-0 items-center justify-center rounded-lg",
            @featured && "bg-white/15 text-white",
            !@featured && tone_class(@tone, :soft)
          ]}
        >
          <.icon name={@icon} class="h-3.5 w-3.5" />
        </span>
      </div>
      <p class={["font-mono font-semibold leading-none tracking-[-0.035em]", @compact && "mt-2 text-[1.12rem]", !@compact && "mt-3 text-[1.42rem]", @featured && "text-white", !@featured && tone_class(@tone)]}>
        <%= @value %>
      </p>
      <p :if={@note} class={["text-[10px] leading-4", @compact && "mt-1.5", !@compact && "mt-2.5", @featured && "text-white/70", !@featured && "text-slate-400"]}>
        <%= @note %>
      </p>
    </div>
    """
  end

  @doc """
  Layered glass panel: a soft blurred glow behind a crisper translucent sheet
  in front. This double-surface stack is what makes it read as physically
  layered glass instead of a flat card with a blur filter on it.
  """
  attr :class, :any, default: nil
  attr :glow, :string, default: nil
  slot :inner_block, required: true

  def glass(assigns) do
    ~H"""
    <div class="relative">
      <div
        :if={@glow}
        class="absolute -inset-1 rounded-[22px] opacity-40 blur-xl"
        style={"background: #{@glow};"}
      >
      </div>
      <div class={[
        "relative rounded-[20px] border border-[var(--fin-glass-border)] bg-[linear-gradient(160deg,var(--fin-glass-from)_0%,var(--fin-glass-to)_100%)] shadow-[0_1px_0_var(--fin-glass-inset)_inset,0_20px_40px_-20px_var(--fin-glass-shadow)] backdrop-blur-xl",
        @class
      ]}>
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true

  def overview_glass_pane(assigns) do
    ~H"""
    <.glass class={["p-5 sm:p-6", @class]}>
      <%= render_slot(@inner_block) %>
    </.glass>
    """
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
        @active_section == @section && "bg-[var(--tone-budget)] text-white shadow-sm xl:bg-white/[0.04] xl:text-[var(--tone-budget)]",
        @active_section != @section && "border border-white/10 bg-white/[0.06] text-slate-400 hover:bg-white/[0.04] hover:text-white xl:border-transparent"
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
        @active_section == @section && "border border-white/10 bg-white/10 text-white shadow-sm",
        @active_section != @section && "text-slate-400 hover:bg-white/[0.04] hover:text-white"
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
    <div class="rounded-xl border border-white/10 bg-white/[0.04] p-4">
      <p class="text-sm font-semibold text-white"><%= @title %></p>
      <p class="mt-1 text-xs text-slate-400"><%= format_date(@month.start_date) %> to <%= format_date(@month.end_date) %></p>
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
      <span class={["text-xs", @active && "font-semibold text-white", !@active && "text-slate-400"]}><%= @label %></span>
    </div>
    """
  end

  @doc """
  Six-month cashflow trend as a grid of tone-colored squares (green = net
  positive, red = net negative), intensity scaled to the largest swing in
  the window. Derived fields (tone/opacity/tooltip) are computed here in
  plain Elixir before the template runs, same pattern as `savings_goal_card`.
  """
  attr :months, :list, required: true

  def cashflow_grid(assigns) do
    months =
      Enum.map(assigns.months, fn month ->
        month
        |> Map.put(:tone, cashflow_tone(month.balance))
        |> Map.put(:opacity, cashflow_opacity(month.intensity))
        |> Map.put(:tooltip, "#{month.label}: #{signed_decimal(month.balance, @default_currency)}")
      end)

    assigns = assign(assigns, :months, months)

    ~H"""
    <div class="grid grid-cols-6 gap-2.5">
      <div :for={month <- @months} class="flex flex-col items-center gap-2">
        <div
          class={["h-11 w-11 rounded-lg sm:h-12 sm:w-12", tone_class(month.tone, :bar)]}
          style={"opacity: #{month.opacity}"}
          title={month.tooltip}
        >
        </div>
        <span class="text-[11px] font-medium text-slate-400"><%= month.label %></span>
      </div>
    </div>
    """
  end

  def cashflow_tone(balance) do
    if Decimal.compare(balance, Decimal.new("0")) == :lt, do: "expense", else: "income"
  end

  @doc """
  Zero-activity months still get a visible floor opacity so the grid never
  shows fully-invisible squares.
  """
  def cashflow_opacity(intensity) do
    Float.round(0.22 + intensity / 100 * 0.78, 2)
  end

  @doc """
  Horizontal segmented bar + dot legend for a category spending breakdown.
  Category colors are user-chosen (set on the category itself), unlike
  status/tone indicators elsewhere, so they're rendered directly rather than
  through `tone_class/2`.
  """
  attr :breakdown, :list, required: true

  def spending_breakdown_card(assigns) do
    ~H"""
    <div>
      <div class="flex h-3 w-full overflow-hidden rounded-full bg-white/5">
        <div
          :for={segment <- @breakdown}
          :if={segment.pct > 0}
          class="h-full first:rounded-l-full last:rounded-r-full"
          style={"width: #{Float.round(segment.pct, 1)}%; background-color: #{segment.color};"}
          title={"#{segment.name} · #{Float.round(segment.pct, 1)}%"}
        >
        </div>
      </div>

      <div class="mt-4 flex flex-wrap gap-x-5 gap-y-2.5">
        <div :for={segment <- @breakdown} class="flex items-center gap-2 text-xs text-slate-400">
          <span class="inline-block h-2.5 w-2.5 rounded-full" style={"background-color: #{segment.color};"}></span>
          <span class="text-slate-300"><%= segment.name %></span>
          <span class="font-mono text-slate-500"><%= round(segment.pct) %>%</span>
        </div>
        <div :if={@breakdown == []} class="text-sm text-slate-500">No spending recorded this month.</div>
      </div>
    </div>
    """
  end

  attr :transaction, Transaction, required: true

  def transaction_table_row(assigns) do
    ~H"""
    <div class="grid grid-cols-[minmax(0,1.2fr)_auto_auto] items-center gap-3 px-5 py-4">
      <div class="min-w-0">
        <p class="truncate font-medium text-white"><%= @transaction.description || review_title(@transaction) %></p>
        <p class="mt-1 text-xs text-slate-400">
          <%= category_name(@transaction.category) %> · <%= format_date(@transaction.transaction_date) %>
        </p>
      </div>
      <p class={["text-right font-mono text-sm font-semibold", tone_class(@transaction.type)]}>
        <%= signed_money(@transaction) %>
      </p>
      <p class="truncate text-right font-mono text-sm text-slate-400">
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
        <span class="font-medium text-white"><%= @status.budget.name %></span>
        <span class="font-mono text-[12px] text-slate-400"><%= money(@status.spent, @status.budget.currency) %> / <%= money(@status.budget.amount, @status.budget.currency) %></span>
      </div>
      <div class="mt-2.5 h-1.5 overflow-hidden rounded-full bg-white/10">
        <div class={["h-full rounded-full", tone_class(budget_state_tone(@status), :bar)]} style={"width: #{budget_remaining_pct(@status.percentage)}%"} />
      </div>
    </div>
    """
  end

  attr :transaction, Transaction, required: true
  attr :compact, :boolean, default: false

  def transaction_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-3 rounded-lg border border-white/10 bg-white/[0.06] p-3">
      <div class="min-w-0">
        <div class="flex flex-wrap items-center gap-2">
          <span class={["text-sm font-semibold", tone_class(@transaction.type)]}>
            <%= signed_money(@transaction) %>
          </span>
          <span class="text-sm font-semibold text-white"><%= @transaction.description || "Transaction" %></span>
        </div>
        <p class="mt-1 text-xs text-slate-400">
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
    <div class="rounded-lg border border-white/10 bg-white/[0.06] p-4">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div class="min-w-0">
          <div class="flex flex-wrap items-center gap-2">
            <span class={["text-sm font-semibold", tone_class(@transaction.type)]}>
              <%= signed_money(@transaction) %>
            </span>
            <span class="text-sm font-semibold text-white"><%= review_title(@transaction) %></span>
            <span class="rounded-full bg-[color-mix(in_srgb,var(--tone-review)_16%,transparent)] px-2 py-1 text-[11px] font-semibold text-[var(--tone-review)]">
              <%= source_label(@transaction.source) %>
            </span>
          </div>
          <p class="mt-1 text-xs text-slate-400">
            <%= format_date(@transaction.transaction_date) %>
            <%= if @transaction.merchant, do: " · #{@transaction.merchant}" %>
            <%= if @transaction.review_reason, do: " · #{@transaction.review_reason}" %>
          </p>
          <p :if={@transaction.raw_description} class="mt-2 text-sm text-slate-400"><%= @transaction.raw_description %></p>
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
    <div class="rounded-lg border border-white/10 bg-white/[0.06] p-4">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p class="font-semibold text-white"><%= @status.budget.name %></p>
          <p class="mt-1 text-xs text-slate-400">
            <%= category_name(@status.budget.category) %> · <%= String.capitalize(@status.budget.period) %>
          </p>
        </div>
        <span class={["rounded-full px-2.5 py-1 text-xs font-semibold", tone_class(budget_state_tone(@status), :soft)]}>
          <%= budget_state_label(@status) %>
        </span>
      </div>

      <div class="mt-4 h-2 overflow-hidden rounded-full bg-white/[0.04]">
        <div class={["h-full rounded-full", tone_class(budget_state_tone(@status), :bar)]} style={"width: #{budget_remaining_pct(@status.percentage)}%"} />
      </div>

      <div class="mt-3 grid grid-cols-3 gap-2 text-xs">
        <div>
          <p class="text-slate-400">Spent</p>
          <p class="mt-1 font-semibold text-white"><%= money(@status.spent, @status.budget.currency) %></p>
        </div>
        <div>
          <p class="text-slate-400">Remaining</p>
          <p class="mt-1 font-semibold text-white"><%= money(@status.remaining, @status.budget.currency) %></p>
        </div>
        <div>
          <p class="text-slate-400">Used</p>
          <p class="mt-1 font-semibold text-white"><%= Float.round(@status.percentage, 1) %>%</p>
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
    <div class="rounded-lg border border-white/10 bg-white/[0.06] p-4">
      <div class="flex items-start justify-between gap-4">
        <div>
          <p class="font-semibold text-white"><%= @debt.name %></p>
          <p class="mt-1 text-xs text-slate-400">
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
          <p class="text-[11px] font-semibold uppercase tracking-wide text-slate-400">Balance</p>
          <p class="mt-1 font-semibold text-white"><%= money(@debt.current_balance, @debt.currency) %></p>
        </div>
        <div>
          <p class="text-[11px] font-semibold uppercase tracking-wide text-slate-400">Minimum</p>
          <p class="mt-1 font-semibold text-white"><%= money(@debt.minimum_payment, @debt.currency) %></p>
        </div>
        <div>
          <p class="text-[11px] font-semibold uppercase tracking-wide text-slate-400">APR</p>
          <p class="mt-1 font-semibold text-white"><%= apr(@debt.apr) %></p>
        </div>
      </div>

      <.form :if={@payment_form_debt_id == @debt.id} for={@payment_form} phx-submit="record_payment" class="mt-4 rounded-lg border border-white/10 bg-white/[0.04] p-4">
        <input type="hidden" name="debt_id" value={@debt.id} />
        <div class="grid gap-3 md:grid-cols-2">
          <.finance_input form={@payment_form} field={:amount} label="Payment amount" placeholder="100.00" type="number" step="0.01" />
          <.finance_input form={@payment_form} field={:payment_date} label="Payment date" type="date" />
          <.finance_select form={@payment_form} field={:kind} label="Kind" options={payment_kind_options()} />
          <label class="flex items-center gap-2 rounded-lg border border-white/10 bg-white/[0.06] px-4 py-3 text-sm font-semibold text-slate-300">
            <input type="hidden" name="payment[create_expense_transaction]" value="false" />
            <input type="checkbox" name="payment[create_expense_transaction]" value="true" checked class="h-4 w-4 rounded border-white/20 text-white" />
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

      <div :if={@debt.payments != []} class="mt-4 rounded-lg bg-white/[0.04] p-3">
        <p class="text-[11px] font-semibold uppercase tracking-wide text-slate-400">Recent payments</p>
        <div class="mt-2 space-y-2">
          <div :for={payment <- @debt.payments} class="flex items-center justify-between gap-3 text-sm">
            <span class="text-slate-400">
              <%= format_date(payment.payment_date) %> · <%= format_kind(payment.kind) %>
            </span>
            <span class="font-semibold text-white"><%= money(payment.amount, @debt.currency) %></span>
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
    <div class="flex items-center justify-between gap-4 border-b border-white/10 py-2 last:border-b-0">
      <span class="text-sm text-slate-400"><%= @label %></span>
      <span class="text-sm font-semibold text-white"><%= @value %></span>
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
      <label for={@field_data.id} class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-slate-400">
        <%= @label %>
      </label>
      <input
        id={@field_data.id}
        name={@field_data.name}
        value={@field_data.value}
        type={@type}
        placeholder={@placeholder}
        step={@step}
        class="w-full rounded-lg border border-white/10 bg-white/[0.06] px-3 py-2.5 text-sm text-white outline-none transition focus:border-[var(--tone-income)] focus:ring-2 focus:ring-[color-mix(in_srgb,var(--tone-income)_25%,transparent)]"
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
      <label for={@field_data.id} class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-slate-400">
        <%= @label %>
      </label>
      <select
        id={@field_data.id}
        name={@field_data.name}
        class="w-full rounded-lg border border-white/10 bg-white/[0.06] px-3 py-2.5 text-sm text-white outline-none transition focus:border-[var(--tone-income)] focus:ring-2 focus:ring-[color-mix(in_srgb,var(--tone-income)_25%,transparent)]"
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
    <div class="rounded-lg border border-white/10 bg-white/[0.06] p-4 shadow-sm">
      <div class="flex items-start justify-between gap-4">
        <div>
          <p class="text-lg font-semibold text-white"><%= String.capitalize(@plan.strategy) %></p>
          <p class="mt-1 text-xs text-slate-400"><%= if @plan.feasible?, do: "Feasible with current cash flow", else: "Needs more cash flow" %></p>
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

      <div class="mt-4 rounded-lg bg-white/[0.04] p-3">
        <p class="text-[11px] font-semibold uppercase tracking-wide text-slate-400">Order</p>
        <p class="mt-1 text-sm text-slate-300"><%= payoff_order(@plan.payoff_order) %></p>
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
      :lt -> "-#{currency_prefix(currency)}#{Decimal.abs(rounded)}"
      _ -> "#{currency_prefix(currency)}#{rounded}"
    end
  end

  def money(nil, currency), do: "#{currency_prefix(currency)}0.00"
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
    do: "bg-[color-mix(in_srgb,var(--tone-budget)_14%,transparent)] text-[var(--tone-budget)]"

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

  def focus_panel_title("budget_overview"), do: "Budget overview"
  def focus_panel_title("activity"), do: "Recent activity"
  def focus_panel_title("signals"), do: "Signals and visibility"
  def focus_panel_title("obligations"), do: "Obligations and payoff plans"
  def focus_panel_title("transaction"), do: "Add transaction"
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

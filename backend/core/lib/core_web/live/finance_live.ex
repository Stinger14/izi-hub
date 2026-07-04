defmodule CoreWeb.FinanceLive do
  use CoreWeb, :live_view

  alias Core.Finance
  alias Core.Finance.{Budget, Category, DebtPayment, Transaction}

  @sections ["overview", "transactions", "review", "budgets", "debts", "insights"]
  @time_scopes ["day", "week", "month", "year", "event"]
  @focus_panels ["budget_overview", "activity", "signals", "obligations"]

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:current_scope, fn -> nil end)
     |> assign(
       page_title: "Finance",
       active_section: "overview",
       ownership_scope: "personal",
       time_scope: "month",
       focus_panel: nil,
       editing_transaction_id: nil,
       debt_form_open: false,
       payment_form_debt_id: nil,
        comparison: []
     )
     |> assign_forms()
     |> assign_finance_data()}
  end

  def handle_event("show_section", %{"section" => section}, socket) when section in @sections do
    {:noreply, assign(socket, active_section: section)}
  end

  def handle_event("show_section", _params, socket), do: {:noreply, socket}

  def handle_event("set_time_scope", %{"scope" => scope}, socket) when scope in @time_scopes do
    {:noreply, socket |> assign(time_scope: scope) |> assign_finance_data()}
  end

  def handle_event("set_time_scope", _params, socket), do: {:noreply, socket}

  def handle_event("set_ownership_scope", %{"scope" => "personal"}, socket) do
    {:noreply, assign(socket, ownership_scope: "personal")}
  end

  def handle_event("set_ownership_scope", _params, socket), do: {:noreply, socket}

  def handle_event("open_focus_panel", %{"panel" => panel}, socket)
      when panel in @focus_panels do
    {:noreply, assign(socket, focus_panel: panel)}
  end

  def handle_event("open_focus_panel", _params, socket), do: {:noreply, socket}

  def handle_event("close_focus_panel", _params, socket) do
    {:noreply, assign(socket, focus_panel: nil)}
  end

  def handle_event("create_transaction", %{"transaction" => params}, socket) do
    user = socket.assigns.current_scope.user

    case Finance.create_transaction(user, params) do
      {:ok, _transaction} ->
        {:noreply,
         socket
         |> put_flash(:info, "Transaction added")
         |> assign(editing_transaction_id: nil)
         |> assign_transaction_form()
         |> assign_finance_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, transaction_form: to_form(changeset, as: :transaction))}
    end
  end

  def handle_event("open_edit_transaction", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user
    transaction = Finance.get_transaction_for_user!(user, id)

    {:noreply,
     socket
     |> assign(
       editing_transaction_id: transaction.id,
       active_section: edit_transaction_section(transaction)
     )
     |> assign_transaction_form(transaction)}
  end

  def handle_event("cancel_transaction_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(editing_transaction_id: nil)
     |> assign_transaction_form()}
  end

  def handle_event("update_transaction", %{"transaction" => params}, socket) do
    user = socket.assigns.current_scope.user
    transaction = Finance.get_transaction_for_user!(user, socket.assigns.editing_transaction_id)

    result =
      if transaction.status == "pending_review" do
        Finance.confirm_transaction(user, transaction, params)
      else
        Finance.update_transaction(user, transaction, params)
      end

    case result do
      {:ok, _transaction} ->
        message =
          if transaction.status == "pending_review",
            do: "Transaction confirmed",
            else: "Transaction updated"

        {:noreply,
         socket
         |> put_flash(:info, message)
         |> assign(editing_transaction_id: nil)
         |> assign_transaction_form()
         |> assign_finance_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, transaction_form: to_form(changeset, as: :transaction))}
    end
  end

  def handle_event("delete_transaction", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user
    transaction = Finance.get_transaction_for_user!(user, id)

    case Finance.delete_transaction(user, transaction) do
      {:ok, _transaction} ->
        {:noreply, socket |> put_flash(:info, "Transaction deleted") |> assign_finance_data()}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Transaction could not be deleted")}
    end
  end

  def handle_event("confirm_transaction", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user
    transaction = Finance.get_transaction_for_user!(user, id)

    case Finance.confirm_transaction(user, transaction) do
      {:ok, _transaction} ->
        {:noreply, socket |> put_flash(:info, "Transaction confirmed") |> assign_finance_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(editing_transaction_id: transaction.id, active_section: "review")
         |> assign(transaction_form: to_form(changeset, as: :transaction))}
    end
  end

  def handle_event("ignore_transaction", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user
    transaction = Finance.get_transaction_for_user!(user, id)

    case Finance.ignore_transaction(user, transaction) do
      {:ok, _transaction} ->
        {:noreply,
         socket
         |> put_flash(:info, "Transaction ignored")
         |> assign_finance_data()}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Transaction could not be ignored")}
    end
  end

  def handle_event("create_category", %{"category" => params}, socket) do
    user = socket.assigns.current_scope.user

    case Finance.create_category(user, params) do
      {:ok, _category} ->
        {:noreply,
         socket
         |> put_flash(:info, "Category added")
         |> assign_category_form()
         |> assign_finance_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, category_form: to_form(changeset, as: :category))}
    end
  end

  def handle_event("create_budget", %{"budget" => params}, socket) do
    user = socket.assigns.current_scope.user

    case Finance.create_budget(user, params) do
      {:ok, _budget} ->
        {:noreply,
         socket
         |> put_flash(:info, "Budget added")
         |> assign_budget_form()
         |> assign_finance_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, budget_form: to_form(changeset, as: :budget))}
    end
  end

  def handle_event("open_debt_form", _params, socket) do
    {:noreply, assign(socket, debt_form_open: true, active_section: "debts")}
  end

  def handle_event("close_debt_form", _params, socket) do
    {:noreply, socket |> assign(debt_form_open: false) |> assign_debt_form()}
  end

  def handle_event("create_debt", %{"debt" => params}, socket) do
    user = socket.assigns.current_scope.user

    case Finance.create_debt(user, params) do
      {:ok, _debt} ->
        {:noreply,
         socket
         |> put_flash(:info, "Debt added")
         |> assign(debt_form_open: false)
         |> assign_debt_form()
         |> assign_payment_form()
         |> assign_finance_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(debt_form_open: true, active_section: "debts")
         |> assign(debt_form: to_form(changeset, as: :debt))}
    end
  end

  def handle_event("open_payment_form", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(payment_form_debt_id: id, debt_form_open: false, active_section: "debts")
     |> assign_payment_form()}
  end

  def handle_event("close_payment_form", _params, socket) do
    {:noreply, socket |> assign(payment_form_debt_id: nil) |> assign_payment_form()}
  end

  def handle_event("record_payment", %{"payment" => params, "debt_id" => debt_id}, socket) do
    user = socket.assigns.current_scope.user
    debt = Finance.get_debt_for_user!(user, debt_id)

    case Finance.record_debt_payment(user, debt, params) do
      {:ok, _payment} ->
        {:noreply,
         socket
         |> put_flash(:info, "Payment recorded")
         |> assign(payment_form_debt_id: nil, comparison: [])
         |> assign_payment_form()
         |> assign_finance_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(payment_form_debt_id: debt_id, active_section: "debts")
         |> assign(payment_form: to_form(changeset, as: :payment))}
    end
  end

  def handle_event("archive_debt", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user
    debt = Finance.get_debt_for_user!(user, id)

    case Finance.delete_debt(user, debt) do
      {:ok, _debt} ->
        {:noreply, socket |> put_flash(:info, "Debt archived") |> assign_finance_data()}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Debt could not be archived")}
    end
  end

  def handle_event("generate_plans", _params, socket) do
    user = socket.assigns.current_scope.user
    comparison = Finance.generate_debt_payoff_comparison(user)
    {:noreply, assign(socket, comparison: comparison, active_section: "debts")}
  end

  def handle_event("save_plan", %{"strategy" => strategy}, socket) do
    user = socket.assigns.current_scope.user
    plan = Enum.find(socket.assigns.comparison, &(&1.strategy == strategy))

    result =
      if plan do
        Finance.save_generated_debt_payoff_plan(user, plan)
      else
        {:error, :missing_plan}
      end

    case result do
      {:ok, _plan} ->
        {:noreply, socket |> put_flash(:info, "Payoff plan saved") |> assign_finance_data()}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Payoff plan could not be saved")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-purple-50 text-slate-900">
        <main class="mx-auto max-w-6xl px-4 pb-16 pt-8 sm:px-6 lg:px-8">
          <.finance_dashboard_header {assigns} />

          <section class="mt-6 rounded-2xl border border-purple-100 bg-white/85 p-5 shadow-sm backdrop-blur">
            <div class="flex flex-wrap items-center justify-between gap-4 border-b border-purple-100 pb-4">
              <div>
                <p class="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Workspace</p>
                <h2 class="mt-2 text-2xl font-semibold tracking-tight text-slate-950">Manage personal finances</h2>
                <p class="mt-2 max-w-3xl text-sm leading-6 text-slate-600">
                  Personal budgets and transactions remain visible only to the signed-in member. Household mode will never reuse this workspace to expose another member's private budget data.
                </p>
              </div>
              <div class="flex flex-wrap gap-2">
                <button
                  type="button"
                  phx-click="open_focus_panel"
                  phx-value-panel="budget_overview"
                  class="btn btn-secondary btn-sm"
                >
                  Budget overview
                </button>
                <button
                  type="button"
                  phx-click="open_focus_panel"
                  phx-value-panel="activity"
                  class="btn btn-secondary btn-sm"
                >
                  Activity
                </button>
                <button
                  type="button"
                  phx-click="open_focus_panel"
                  phx-value-panel="signals"
                  class="btn btn-secondary btn-sm"
                >
                  Signals
                </button>
                <button
                  type="button"
                  phx-click="open_focus_panel"
                  phx-value-panel="obligations"
                  class="btn btn-secondary btn-sm"
                >
                  Obligations
                </button>
                <button
                  :if={@active_section != "review" and @pending_review_count > 0}
                  type="button"
                  phx-click="show_section"
                  phx-value-section="review"
                  class="btn btn-secondary btn-sm"
                >
                  Open review queue
                </button>
              </div>
            </div>

            <nav class="mt-5 flex gap-2 overflow-x-auto pb-1">
              <.section_button active_section={@active_section} section="overview" label="Snapshot" />
              <.section_button active_section={@active_section} section="transactions" label="Transactions" />
              <.section_button active_section={@active_section} section="review" label={review_section_label(@pending_review_count)} />
              <.section_button active_section={@active_section} section="budgets" label="Budgets" />
              <.section_button active_section={@active_section} section="debts" label="Debts" />
              <.section_button active_section={@active_section} section="insights" label="Insights" />
            </nav>

            <div class="mt-6">
              <.overview_section :if={@active_section == "overview"} {assigns} />
              <.transactions_section :if={@active_section == "transactions"} {assigns} />
              <.review_section :if={@active_section == "review"} {assigns} />
              <.budgets_section :if={@active_section == "budgets"} {assigns} />
              <.debts_section :if={@active_section == "debts"} {assigns} />
              <.insights_section :if={@active_section == "insights"} {assigns} />
            </div>
          </section>

          <.focus_panel_modal :if={@focus_panel} panel={@focus_panel} {assigns} />
        </main>
      </div>
    </Layouts.app>
    """
  end

  defp finance_dashboard_header(assigns) do
    ~H"""
    <section class="overflow-hidden rounded-2xl border border-purple-100 bg-white/85 shadow-sm backdrop-blur">
      <div class="border-b border-purple-100 bg-[radial-gradient(circle_at_top_left,_rgba(168,85,247,0.14),_transparent_42%),linear-gradient(180deg,_rgba(255,255,255,0.98)_0%,_rgba(250,245,255,0.84)_100%)] px-5 py-5 sm:px-6">
        <div class="flex flex-wrap items-start justify-between gap-5">
          <div class="max-w-3xl">
            <p class="text-xs font-semibold uppercase tracking-[0.24em] text-purple-500">Finance</p>
            <h1 class="mt-2 text-3xl font-semibold tracking-tight text-slate-950 sm:text-4xl">
              <%= finance_title(@ownership_scope, @current_scope) %>
            </h1>
            <p class="mt-3 text-sm leading-6 text-slate-600">
              Available cash, budget remaining, and review items stay visible first. Personal budgets remain private to their owner, and admin extras stay operational-only.
            </p>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <div class="inline-flex items-center gap-1 rounded-full border border-purple-100 bg-white/90 p-1 shadow-sm">
              <button
                type="button"
                phx-click="set_ownership_scope"
                phx-value-scope="personal"
                class="inline-flex h-9 w-9 items-center justify-center rounded-full bg-purple-600 text-white"
                aria-label="Personal finance scope"
                title="My finances"
              >
                <.icon name="hero-user" class="h-4 w-4" />
              </button>
              <button
                type="button"
                disabled
                class="inline-flex h-9 w-9 items-center justify-center rounded-full text-slate-400"
                aria-label="Household finance scope coming soon"
                title="Household coming soon"
              >
                <.icon name="hero-home" class="h-4 w-4" />
              </button>
            </div>

            <div class="rounded-full border border-purple-100 bg-white/90 px-3 py-2 text-xs font-semibold text-slate-600 shadow-sm">
              <%= @date_window_label %>
            </div>

            <button type="button" phx-click="show_section" phx-value-section="transactions" class="btn btn-primary btn-sm">
              Add expense
            </button>
            <button type="button" phx-click="show_section" phx-value-section="budgets" class="btn btn-secondary btn-sm">
              Create budget
            </button>
            <button type="button" phx-click="show_section" phx-value-section="debts" class="btn btn-secondary btn-sm">
              Manage debt
            </button>
            <.link
              :if={admin_user?(@current_scope)}
              navigate={~p"/admin/finops"}
              class="btn btn-ghost btn-sm text-slate-700"
            >
              Admin tools
            </.link>
          </div>
        </div>
      </div>

      <div class="px-5 py-5 sm:px-6">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div class="inline-flex flex-wrap items-center gap-2 rounded-full border border-purple-100 bg-purple-50/70 p-1">
            <.time_scope_button current={@time_scope} scope="day" />
            <.time_scope_button current={@time_scope} scope="week" />
            <.time_scope_button current={@time_scope} scope="month" />
            <.time_scope_button current={@time_scope} scope="year" />
            <.time_scope_button current={@time_scope} scope="event" />
          </div>

          <div class="flex flex-wrap items-center gap-2 text-xs text-slate-500">
            <span class="inline-flex items-center gap-1 rounded-full border border-purple-100 bg-white px-3 py-1.5 font-semibold text-purple-600">
              <.icon name="hero-lock-closed" class="h-3.5 w-3.5" />
              Private by default
            </span>
            <span :if={admin_user?(@current_scope)} class="inline-flex items-center gap-1 rounded-full border border-purple-100 bg-white px-3 py-1.5 font-semibold text-slate-600">
              <.icon name="hero-shield-check" class="h-3.5 w-3.5 text-purple-500" />
              Admin tools visible
            </span>
          </div>
        </div>

        <div class="mt-5 grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
          <.metric_card
            label="Available cash"
            value={money(@period_summary.balance)}
            note={time_scope_summary_note(@time_scope, @date_window_label)}
            tone="cash"
          />
          <.metric_card
            label="Budget remaining"
            value={money(@budget_remaining)}
            note="#{length(@budget_statuses)} active budgets"
            tone="budget"
          />
          <.metric_card
            label="Income"
            value={money(@period_summary.income)}
            note={@date_window_label}
            tone="income"
          />
          <.metric_card
            label="Expenses"
            value={money(@period_summary.expenses)}
            note="#{length(@transactions)} transactions in view"
            tone="expense"
          />
          <.metric_card
            label="Pending review"
            value={Integer.to_string(@pending_review_count)}
            note="Personal queue only"
            tone="review"
          />
        </div>
      </div>
    </section>
    """
  end

  attr :current, :string, required: true
  attr :scope, :string, required: true

  defp time_scope_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="set_time_scope"
      phx-value-scope={@scope}
      class={[
        "rounded-full px-3 py-1.5 text-xs font-semibold transition",
        @current == @scope && "bg-white text-purple-600 shadow-sm",
        @current != @scope && "text-slate-500 hover:bg-white/80 hover:text-slate-900"
      ]}
    >
      <%= time_scope_title(@scope) %>
    </button>
    """
  end

  defp budget_overview_panel(assigns) do
    ~H"""
    <section class="rounded-2xl border border-purple-100 bg-white/85 p-5 shadow-sm backdrop-blur">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Budget overview</p>
          <h2 class="mt-2 text-2xl font-semibold tracking-tight text-slate-950">Planned spending and event envelopes</h2>
        </div>
        <button type="button" phx-click="show_section" phx-value-section="budgets" class="btn btn-secondary btn-xs">
          Open budgets
        </button>
      </div>

      <div class="mt-5 grid gap-4 xl:grid-cols-[1.1fr_0.9fr]">
        <div class="space-y-3">
          <.budget_status_card :for={status <- Enum.take(@budget_statuses, 3)} status={status} />
          <div :if={@budget_statuses == []} class="rounded-xl border border-dashed border-purple-100 bg-purple-50/50 p-4 text-sm text-slate-500">
            Create your first personal budget to start tracking daily, weekly, monthly, or yearly targets.
          </div>
        </div>

        <div class="rounded-xl border border-purple-100 bg-purple-50/55 p-4">
          <div class="flex items-center justify-between gap-3">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Event budgets</p>
              <h3 class="mt-2 text-lg font-semibold text-slate-950">Custom date ranges</h3>
            </div>
            <span class="rounded-full border border-purple-100 bg-white px-3 py-1 text-xs font-semibold text-slate-600">
              <%= length(@event_budget_statuses) %> active
            </span>
          </div>

          <div class="mt-4 space-y-3">
            <div :for={status <- Enum.take(@event_budget_statuses, 3)} class="rounded-xl border border-purple-100 bg-white p-4">
              <div class="flex items-start justify-between gap-3">
                <div>
                  <p class="font-semibold text-slate-900"><%= status.budget.name %></p>
                  <p class="mt-1 text-xs text-slate-500">
                    <%= format_date(status.budget.start_date) %> to <%= format_date(status.budget.end_date) %>
                  </p>
                </div>
                <span class={["rounded-full px-2.5 py-1 text-xs font-semibold", budget_state_class(status)]}>
                  <%= budget_state_label(status) %>
                </span>
              </div>
              <div class="mt-4 h-2 overflow-hidden rounded-full bg-slate-100">
                <div class={["h-full rounded-full", budget_progress_class(status)]} style={"width: #{min(status.percentage, 100)}%"} />
              </div>
              <div class="mt-3 flex items-center justify-between text-xs">
                <span class="text-slate-500">Spent <%= money(status.spent) %></span>
                <span class="font-semibold text-slate-900">Remaining <%= money(status.remaining) %></span>
              </div>
            </div>

            <div :if={@event_budget_statuses == []} class="rounded-xl border border-dashed border-purple-100 bg-white p-4 text-sm text-slate-500">
              Use a custom budget period for trips, birthdays, repairs, or any event you want to track separately.
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp signals_panel(assigns) do
    ~H"""
    <section class="rounded-2xl border border-purple-100 bg-white/85 p-5 shadow-sm backdrop-blur">
      <div class="flex flex-wrap items-start justify-between gap-4">
        <div>
          <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Signals</p>
          <h2 class="mt-2 text-2xl font-semibold tracking-tight text-slate-950">Cash picture, visibility, and rules</h2>
        </div>
        <button type="button" phx-click="show_section" phx-value-section="insights" class="btn btn-secondary btn-xs">
          Insights
        </button>
      </div>

      <div class="mt-5 grid gap-3 sm:grid-cols-2">
        <div class="rounded-xl border border-purple-100 bg-purple-50/55 p-4">
          <p class="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">Net flow</p>
          <p class={["mt-2 text-2xl font-semibold tracking-tight", metric_tone_class("cash")]}>
            <%= money(@period_summary.balance) %>
          </p>
          <p class="mt-2 text-sm text-slate-600">Income minus expenses for <%= String.downcase(time_scope_title(@time_scope)) %>.</p>
        </div>
        <div class="rounded-xl border border-purple-100 bg-purple-50/55 p-4">
          <p class="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">Visibility note</p>
          <p class="mt-2 text-sm leading-6 text-slate-600">
            Personal and household bank accounts will appear here once account records are added. Until then, this panel shows spending grouped by payment method to keep the dashboard practical without pretending to know balances.
          </p>
        </div>
      </div>

      <div class="mt-5 grid gap-3 lg:grid-cols-[0.9fr_1.1fr]">
        <div class="space-y-3">
          <div :for={rail <- @payment_method_breakdown} class="flex items-center justify-between gap-4 rounded-xl border border-purple-100 bg-white p-4">
            <div>
              <p class="font-semibold text-slate-900"><%= rail.label %></p>
              <p class="mt-1 text-xs text-slate-500"><%= rail.count %> transactions in view</p>
            </div>
            <span class="text-sm font-semibold text-slate-900"><%= money(rail.amount) %></span>
          </div>

          <div :if={@payment_method_breakdown == []} class="rounded-xl border border-dashed border-purple-100 bg-purple-50/50 p-4 text-sm text-slate-500">
            No confirmed transactions for this time lens yet.
          </div>
        </div>

        <div class="space-y-3">
          <div :for={warning <- @health.warnings} class="rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">
            <%= warning %>
          </div>
          <div :if={@health.warnings == []} class="rounded-xl border border-emerald-200 bg-emerald-50/80 p-4 text-sm text-emerald-900">
            No financial health warnings for this personal snapshot.
          </div>
          <div class="rounded-xl border border-purple-100 bg-white p-4 text-sm leading-6 text-slate-600">
            <p class="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Privacy rule</p>
            <p class="mt-3">
              Personal budgets, balances, and transactions are scoped to the member who owns them. Admin-only actions support operations only and must not reveal another member's personal budget details.
            </p>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp activity_panel(assigns) do
    ~H"""
    <section class="rounded-2xl border border-purple-100 bg-white/85 p-5 shadow-sm backdrop-blur">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Activity</p>
          <h2 class="mt-2 text-2xl font-semibold tracking-tight text-slate-950">Recent movements and review queue</h2>
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
        <div :if={@transactions == []} class="rounded-xl border border-dashed border-purple-100 bg-purple-50/50 p-4 text-sm text-slate-500">
          No transactions recorded for this period.
        </div>
      </div>

      <div class="mt-5 rounded-xl border border-purple-100 bg-purple-50/55 p-4">
        <div class="flex items-center justify-between gap-3">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Pending review</p>
            <h3 class="mt-2 text-lg font-semibold text-slate-950">Imported suggestions</h3>
          </div>
          <span class="rounded-full border border-purple-100 bg-white px-3 py-1 text-xs font-semibold text-slate-600">
            <%= @pending_review_count %> waiting
          </span>
        </div>

        <div class="mt-4 space-y-3">
          <.review_row :for={transaction <- Enum.take(@pending_transactions, 2)} transaction={transaction} compact />
          <div :if={@pending_transactions == []} class="rounded-xl border border-dashed border-purple-100 bg-white p-4 text-sm text-slate-500">
            No personal transactions are waiting for review.
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp obligations_panel(assigns) do
    ~H"""
    <section class="rounded-2xl border border-purple-100 bg-white/85 p-5 shadow-sm backdrop-blur">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Obligations</p>
          <h2 class="mt-2 text-2xl font-semibold tracking-tight text-slate-950">Debt commitments and payoff planning</h2>
        </div>
        <button type="button" phx-click="show_section" phx-value-section="debts" class="btn btn-secondary btn-xs">
          Open debts
        </button>
      </div>

      <div class="mt-5 grid gap-4 lg:grid-cols-[1fr_0.92fr]">
        <div class="space-y-3">
          <div :for={debt <- Enum.take(@debts, 4)} class="rounded-xl border border-purple-100 bg-purple-50/55 p-4">
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="font-semibold text-slate-900"><%= debt.name %></p>
                <p class="mt-1 text-xs text-slate-500">
                  <%= format_kind(debt.kind) %><%= if debt.provider, do: " with #{debt.provider}" %>
                </p>
              </div>
              <span class="text-sm font-semibold text-slate-900"><%= money(debt.minimum_payment) %></span>
            </div>
            <div class="mt-3 flex flex-wrap items-center justify-between gap-2 text-xs">
              <span class="text-slate-500"><%= due_day_label(debt.due_day) %></span>
              <span class="font-semibold text-slate-900">Balance <%= money(debt.current_balance) %></span>
            </div>
          </div>

          <div :if={@debts == []} class="rounded-xl border border-dashed border-purple-100 bg-purple-50/50 p-4 text-sm text-slate-500">
            No active debts yet. Add one if you want repayment planning and obligations on the dashboard.
          </div>
        </div>

        <div class="rounded-xl border border-purple-100 bg-white p-4">
          <p class="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Saved plans</p>
          <div class="mt-4 space-y-3">
            <div :for={plan <- Enum.take(@plans, 3)} class="rounded-xl border border-purple-100 bg-purple-50/55 p-4">
              <div class="flex items-center justify-between gap-3">
                <p class="font-semibold text-slate-900"><%= plan.name %></p>
                <span class="text-xs font-semibold text-slate-500"><%= format_date(plan.target_payoff_date) %></span>
              </div>
              <p class="mt-2 text-xs text-slate-500">
                <%= String.capitalize(plan.strategy) %> · <%= money(plan.monthly_amount) %>/mo
              </p>
            </div>

            <div :if={@plans == []} class="rounded-xl border border-dashed border-purple-100 bg-purple-50/50 p-4 text-sm text-slate-500">
              Generate and save debt payoff plans to keep them visible here.
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :panel, :string, required: true

  defp focus_panel_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6">
      <button
        type="button"
        phx-click="close_focus_panel"
        class="absolute inset-0 bg-slate-900/45 backdrop-blur-[2px]"
        aria-label="Close detail panel"
      >
      </button>

      <div class="relative z-10 w-full max-w-5xl overflow-hidden rounded-2xl border border-purple-100 bg-white shadow-2xl">
        <div class="flex items-center justify-between gap-4 border-b border-purple-100 px-5 py-4 sm:px-6">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Detail panel</p>
            <h3 class="mt-2 text-2xl font-semibold tracking-tight text-slate-950">
              <%= focus_panel_title(@panel) %>
            </h3>
          </div>
          <button type="button" phx-click="close_focus_panel" class="btn btn-ghost btn-xs">
            <.icon name="hero-x-mark" class="h-4 w-4" />
          </button>
        </div>

        <div class="max-h-[80vh] overflow-y-auto bg-purple-50/50 p-5 sm:p-6">
          <.budget_overview_panel :if={@panel == "budget_overview"} {assigns} />
          <.activity_panel :if={@panel == "activity"} {assigns} />
          <.signals_panel :if={@panel == "signals"} {assigns} />
          <.obligations_panel :if={@panel == "obligations"} {assigns} />
        </div>
      </div>
    </div>
    """
  end

  defp overview_section(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[1fr_0.85fr]">
      <div class="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">This month</p>
            <h2 class="mt-1 text-xl font-semibold text-slate-950">Cash flow</h2>
          </div>
          <span class="rounded-full border border-slate-200 px-3 py-1 text-xs font-semibold text-slate-600">
            <%= format_date(@health.current_month.start_date) %> to <%= format_date(@health.current_month.end_date) %>
          </span>
        </div>

        <div class="mt-5 grid gap-3 md:grid-cols-2">
          <.month_card title="Current month" month={@health.current_month} />
          <.month_card title="Projected next month" month={@health.next_month} />
        </div>
      </div>

      <div class="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
        <div class="flex items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Recent activity</p>
            <h2 class="mt-1 text-xl font-semibold text-slate-950">Latest transactions</h2>
          </div>
          <button type="button" phx-click="show_section" phx-value-section="transactions" class="btn btn-secondary btn-xs">
            View all
          </button>
        </div>

        <div class="mt-4 space-y-3">
          <.transaction_row :for={transaction <- Enum.take(@transactions, 5)} transaction={transaction} compact />
          <div :if={@transactions == []} class="rounded-lg border border-dashed border-slate-200 p-4 text-sm text-slate-500">
            No transactions recorded yet.
          </div>
        </div>
      </div>

      <div class="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
        <div class="flex items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Review queue</p>
            <h2 class="mt-1 text-xl font-semibold text-slate-950">Pending suggestions</h2>
          </div>
          <button type="button" phx-click="show_section" phx-value-section="review" class="btn btn-secondary btn-xs">
            Open review
          </button>
        </div>

        <div class="mt-4 space-y-3">
          <.review_row :for={transaction <- Enum.take(@pending_transactions, 3)} transaction={transaction} compact />
          <div :if={@pending_transactions == []} class="rounded-lg border border-dashed border-slate-200 p-4 text-sm text-slate-500">
            No transactions waiting for review.
          </div>
        </div>
      </div>

      <div class="rounded-lg border border-slate-200 bg-white p-5 shadow-sm xl:col-span-2">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Budgets and debt</p>
            <h2 class="mt-1 text-xl font-semibold text-slate-950">Where attention is needed</h2>
          </div>
          <button type="button" phx-click="show_section" phx-value-section="insights" class="btn btn-secondary btn-xs">
            Insights
          </button>
        </div>

        <div class="mt-4 grid gap-4 lg:grid-cols-2">
          <div class="space-y-3">
            <.budget_status_card :for={status <- Enum.take(@budget_statuses, 3)} status={status} />
            <div :if={@budget_statuses == []} class="rounded-lg border border-dashed border-slate-200 p-4 text-sm text-slate-500">
              Create budgets to see spending guardrails here.
            </div>
          </div>

          <div class="rounded-lg border border-slate-100 bg-slate-50 p-4">
            <.status_row label="Debt-to-income" value={"#{@health.debt_to_income_ratio}%"} />
            <.status_row label="Minimum burden" value={"#{@health.minimum_payment_burden}%"} />
            <.status_row label="Monthly minimums" value={money(@health.minimum_debt_payment)} />
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp transactions_section(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[0.82fr_1.18fr]">
      <div class="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Manual capture</p>
        <h2 class="mt-1 text-xl font-semibold text-slate-950"><%= transaction_form_title(@editing_transaction_id) %></h2>

        <.form for={@transaction_form} phx-submit={transaction_submit(@editing_transaction_id)} class="mt-5 space-y-4">
          <div class="grid gap-3 sm:grid-cols-2">
            <.finance_select form={@transaction_form} field={:type} label="Type" options={transaction_type_options()} />
            <.finance_input form={@transaction_form} field={:amount} label="Amount" placeholder="125.00" type="number" step="0.01" />
            <.finance_input form={@transaction_form} field={:transaction_date} label="Date" type="date" />
            <.finance_select form={@transaction_form} field={:payment_method} label="Method" options={payment_method_options()} />
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

      <div class="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Ledger</p>
            <h2 class="mt-1 text-xl font-semibold text-slate-950">Recent transactions</h2>
          </div>
          <span class="text-xs font-semibold text-slate-500"><%= length(@transactions) %> shown</span>
        </div>

        <div class="mt-4 space-y-3">
          <.transaction_row :for={transaction <- @transactions} transaction={transaction} />
          <div :if={@transactions == []} class="rounded-lg border border-dashed border-slate-200 p-4 text-sm text-slate-500">
            Add income and expenses to start tracking cash flow.
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp review_section(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[1.1fr_0.9fr]">
      <div class="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Pending review</p>
            <h2 class="mt-1 text-xl font-semibold text-slate-950">Imported transaction suggestions</h2>
          </div>
          <span class="text-xs font-semibold text-slate-500"><%= @pending_review_count %> waiting</span>
        </div>

        <div class="mt-4 space-y-3">
          <.review_row :for={transaction <- @pending_transactions} transaction={transaction} />
          <div :if={@pending_transactions == []} class="rounded-lg border border-dashed border-slate-200 p-4 text-sm text-slate-500">
            No pending items right now.
          </div>
        </div>
      </div>

      <div class="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">How review works</p>
        <h2 class="mt-1 text-xl font-semibold text-slate-950">Suggested workflow</h2>
        <div class="mt-5 space-y-3 text-sm leading-6 text-slate-600">
          <p>Imported bank or email candidates land here first with a pending status.</p>
          <p>Confirming moves the transaction into the confirmed ledger and lets it affect budgets and health metrics.</p>
          <p>Editing a pending item in the transaction form will save and confirm it in one step.</p>
        </div>
      </div>
    </section>
    """
  end

  defp budgets_section(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[0.82fr_1.18fr]">
      <div class="space-y-5">
        <div class="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
          <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Spending plan</p>
          <h2 class="mt-1 text-xl font-semibold text-slate-950">Create budget</h2>

          <.form for={@budget_form} phx-submit="create_budget" class="mt-5 space-y-4">
            <.finance_input form={@budget_form} field={:name} label="Name" placeholder="Groceries, rent, subscriptions..." />
            <div class="grid gap-3 sm:grid-cols-2">
              <.finance_input form={@budget_form} field={:amount} label="Amount" placeholder="400.00" type="number" step="0.01" />
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

        <div class="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
          <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Categories</p>
          <h2 class="mt-1 text-xl font-semibold text-slate-950">Add category</h2>

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

      <div class="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Active budgets</p>
            <h2 class="mt-1 text-xl font-semibold text-slate-950">Budget status</h2>
          </div>
          <span class="text-xs font-semibold text-slate-500"><%= money(@budget_remaining) %> remaining</span>
        </div>

        <div class="mt-4 space-y-3">
          <.budget_status_card :for={status <- @budget_statuses} status={status} />
          <div :if={@budget_statuses == []} class="rounded-lg border border-dashed border-slate-200 p-4 text-sm text-slate-500">
            No active budgets yet.
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp debts_section(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
      <div class="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
        <div class="flex items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Debts</p>
            <h2 class="mt-1 text-xl font-semibold text-slate-950">Balances</h2>
          </div>
          <button type="button" phx-click="open_debt_form" class="btn btn-secondary btn-xs">Add</button>
        </div>

        <.form :if={@debt_form_open} for={@debt_form} phx-submit="create_debt" class="mt-5 rounded-lg border border-slate-200 bg-slate-50 p-4">
          <div class="grid gap-3 md:grid-cols-2">
            <.finance_input form={@debt_form} field={:name} label="Name" placeholder="Visa, auto loan..." />
            <.finance_input form={@debt_form} field={:provider} label="Provider" placeholder="Bank or lender" />
            <.finance_select form={@debt_form} field={:kind} label="Kind" options={debt_kind_options()} />
            <.finance_input form={@debt_form} field={:current_balance} label="Current balance" placeholder="2500.00" type="number" step="0.01" />
            <.finance_input form={@debt_form} field={:minimum_payment} label="Minimum payment" placeholder="75.00" type="number" step="0.01" />
            <.finance_input form={@debt_form} field={:apr} label="APR optional" placeholder="24.99" type="number" step="0.0001" />
            <.finance_input form={@debt_form} field={:due_day} label="Due day" placeholder="15" type="number" step="1" />
            <.finance_input form={@debt_form} field={:payoff_goal_date} label="Goal date" type="date" />
          </div>

          <div class="mt-4 flex justify-end gap-2">
            <button type="button" phx-click="close_debt_form" class="btn btn-ghost btn-xs">Cancel</button>
            <button type="submit" class="btn btn-primary btn-xs">Save debt</button>
          </div>
        </.form>

        <div class="mt-5 space-y-3">
          <div :if={@debts == []} class="rounded-lg border border-dashed border-slate-200 p-4 text-sm text-slate-500">
            Add debts to compare payoff strategies.
          </div>

          <.debt_card :for={debt <- @debts} debt={debt} payment_form={@payment_form} payment_form_debt_id={@payment_form_debt_id} />
        </div>
      </div>

      <div class="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Payoff comparison</p>
            <h2 class="mt-1 text-xl font-semibold text-slate-950">Snowball vs avalanche</h2>
          </div>
          <button type="button" phx-click="generate_plans" class="btn btn-primary btn-xs">Refresh</button>
        </div>

        <div class="mt-5 grid gap-4 lg:grid-cols-2">
          <.plan_card :for={plan <- @comparison} plan={plan} />
          <div :if={@comparison == []} class="rounded-lg border border-dashed border-slate-200 p-4 text-sm text-slate-500 lg:col-span-2">
            Generate plans to compare payoff order, payoff month, and estimated interest.
          </div>
        </div>

        <div class="mt-6">
          <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Saved plans</p>
          <div class="mt-3 space-y-2">
            <div :if={@plans == []} class="rounded-lg border border-slate-200 bg-slate-50 p-4 text-sm text-slate-500">
              No saved payoff plans yet.
            </div>
            <div :for={plan <- @plans} class="flex items-center justify-between gap-4 rounded-lg border border-slate-200 bg-white p-4">
              <div>
                <p class="font-semibold text-slate-900"><%= plan.name %></p>
                <p class="mt-1 text-xs text-slate-500">
                  <%= String.capitalize(plan.strategy) %> · <%= money(plan.monthly_amount) %>/mo
                </p>
              </div>
              <span class="text-xs font-semibold text-emerald-700"><%= format_date(plan.target_payoff_date) %></span>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp insights_section(assigns) do
    ~H"""
    <section class="grid gap-5 lg:grid-cols-2">
      <div class="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Signals</p>
        <h2 class="mt-1 text-xl font-semibold text-slate-950">Financial health</h2>

        <div class="mt-5 space-y-3">
          <.status_row label="Debt-to-income" value={"#{@health.debt_to_income_ratio}%"} />
          <.status_row label="Minimum payment burden" value={"#{@health.minimum_payment_burden}%"} />
          <.status_row label="Monthly debt minimums" value={money(@health.minimum_debt_payment)} />
          <.status_row label="Current free cash flow" value={money(@health.current_month.free_cash_flow)} />
        </div>
      </div>

      <div class="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Review queue foundation</p>
        <h2 class="mt-1 text-xl font-semibold text-slate-950">Automation-ready workflow</h2>
        <div class="mt-5 space-y-3 text-sm leading-6 text-slate-600">
          <p>
            Manual transactions are the confirmed ledger. Future email or bank imports should create pending transaction suggestions before they affect the dashboard.
          </p>
          <p>
            Useful fields for that future slice: source, status, external fingerprint, merchant, raw snippet, confidence, and review reason.
          </p>
        </div>
      </div>

      <div class="rounded-lg border border-slate-200 bg-white p-5 shadow-sm lg:col-span-2">
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Warnings</p>
        <div class="mt-4 space-y-2">
          <div :for={warning <- @health.warnings} class="rounded-lg border border-amber-200 bg-amber-50 p-3 text-sm text-amber-900">
            <%= warning %>
          </div>
          <div :if={@health.warnings == []} class="rounded-lg border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-900">
            No financial health warnings for the current snapshot.
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :tone, :string, default: "cash"
  attr :note, :string, default: nil

  defp metric_card(assigns) do
    ~H"""
    <div class="rounded-xl border border-purple-100 bg-white p-4 shadow-sm transition duration-200 hover:-translate-y-0.5">
      <p class="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-400"><%= @label %></p>
      <p class={["mt-2 text-2xl font-semibold tracking-tight", metric_tone_class(@tone)]}><%= @value %></p>
      <p :if={@note} class="mt-2 text-xs leading-5 text-slate-500"><%= @note %></p>
    </div>
    """
  end

  attr :active_section, :string, required: true
  attr :section, :string, required: true
  attr :label, :string, required: true

  defp section_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="show_section"
      phx-value-section={@section}
      class={[
        "shrink-0 rounded-full px-3 py-2 text-sm font-semibold transition",
        @active_section == @section && "bg-purple-600 text-white",
        @active_section != @section && "text-slate-600 hover:bg-purple-50 hover:text-slate-950"
      ]}
    >
      <%= @label %>
    </button>
    """
  end

  attr :title, :string, required: true
  attr :month, :map, required: true

  defp month_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-slate-200 bg-slate-50 p-4">
      <p class="text-sm font-semibold text-slate-900"><%= @title %></p>
      <p class="mt-1 text-xs text-slate-500"><%= format_date(@month.start_date) %> to <%= format_date(@month.end_date) %></p>
      <div class="mt-4 space-y-2 text-sm">
        <.status_row label="Income" value={money(@month.income)} />
        <.status_row label="Expenses" value={money(@month.expenses)} />
        <.status_row label="Free cash flow" value={money(@month.free_cash_flow)} />
      </div>
    </div>
    """
  end

  attr :transaction, Transaction, required: true
  attr :compact, :boolean, default: false

  defp transaction_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-3 rounded-lg border border-slate-200 bg-white p-3">
      <div class="min-w-0">
        <div class="flex flex-wrap items-center gap-2">
          <span class={["text-sm font-semibold", transaction_type_class(@transaction.type)]}>
            <%= signed_money(@transaction) %>
          </span>
          <span class="text-sm font-semibold text-slate-900"><%= @transaction.description || "Transaction" %></span>
        </div>
        <p class="mt-1 text-xs text-slate-500">
          <%= format_date(@transaction.transaction_date) %>
          <%= if @transaction.category, do: " · #{@transaction.category.name}" %>
          <%= if @transaction.payment_method, do: " · #{format_kind(@transaction.payment_method)}" %>
        </p>
      </div>
      <div class="flex items-center gap-2">
        <span :if={show_status_badge?(@transaction)} class={["rounded-full px-2 py-1 text-[11px] font-semibold", transaction_status_class(@transaction.status)]}>
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
          class="btn btn-ghost btn-xs text-rose-600"
        >
          Delete
        </button>
      </div>
    </div>
    """
  end

  attr :transaction, Transaction, required: true
  attr :compact, :boolean, default: false

  defp review_row(assigns) do
    ~H"""
    <div class="rounded-lg border border-slate-200 bg-white p-4">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div class="min-w-0">
          <div class="flex flex-wrap items-center gap-2">
            <span class={["text-sm font-semibold", transaction_type_class(@transaction.type)]}>
              <%= signed_money(@transaction) %>
            </span>
            <span class="text-sm font-semibold text-slate-900"><%= review_title(@transaction) %></span>
            <span class="rounded-full bg-amber-100 px-2 py-1 text-[11px] font-semibold text-amber-800">
              <%= source_label(@transaction.source) %>
            </span>
          </div>
          <p class="mt-1 text-xs text-slate-500">
            <%= format_date(@transaction.transaction_date) %>
            <%= if @transaction.merchant, do: " · #{@transaction.merchant}" %>
            <%= if @transaction.review_reason, do: " · #{@transaction.review_reason}" %>
          </p>
          <p :if={@transaction.raw_description} class="mt-2 text-sm text-slate-600"><%= @transaction.raw_description %></p>
        </div>

        <div class="flex items-center gap-2">
          <span :if={is_number(@transaction.confidence)} class={["rounded-full px-2 py-1 text-[11px] font-semibold", confidence_class(@transaction.confidence)]}>
            <%= confidence_label(@transaction.confidence) %>
          </span>
          <div :if={!@compact} class="flex gap-2">
            <button type="button" phx-click="confirm_transaction" phx-value-id={@transaction.id} class="btn btn-primary btn-xs">
              Confirm
            </button>
            <button type="button" phx-click="open_edit_transaction" phx-value-id={@transaction.id} class="btn btn-secondary btn-xs">
              Edit
            </button>
            <button type="button" phx-click="ignore_transaction" phx-value-id={@transaction.id} class="btn btn-ghost btn-xs text-rose-600">
              Ignore
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :status, :map, required: true

  defp budget_status_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-slate-200 bg-white p-4">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p class="font-semibold text-slate-900"><%= @status.budget.name %></p>
          <p class="mt-1 text-xs text-slate-500">
            <%= category_name(@status.budget.category) %> · <%= String.capitalize(@status.budget.period) %>
          </p>
        </div>
        <span class={["rounded-full px-2.5 py-1 text-xs font-semibold", budget_state_class(@status)]}>
          <%= budget_state_label(@status) %>
        </span>
      </div>

      <div class="mt-4 h-2 overflow-hidden rounded-full bg-slate-100">
        <div class={["h-full rounded-full", budget_progress_class(@status)]} style={"width: #{min(@status.percentage, 100)}%"} />
      </div>

      <div class="mt-3 grid grid-cols-3 gap-2 text-xs">
        <div>
          <p class="text-slate-400">Spent</p>
          <p class="mt-1 font-semibold text-slate-900"><%= money(@status.spent) %></p>
        </div>
        <div>
          <p class="text-slate-400">Remaining</p>
          <p class="mt-1 font-semibold text-slate-900"><%= money(@status.remaining) %></p>
        </div>
        <div>
          <p class="text-slate-400">Used</p>
          <p class="mt-1 font-semibold text-slate-900"><%= Float.round(@status.percentage, 1) %>%</p>
        </div>
      </div>
    </div>
    """
  end

  attr :debt, :any, required: true
  attr :payment_form, :any, required: true
  attr :payment_form_debt_id, :string, default: nil

  defp debt_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-slate-200 bg-white p-4">
      <div class="flex items-start justify-between gap-4">
        <div>
          <p class="font-semibold text-slate-900"><%= @debt.name %></p>
          <p class="mt-1 text-xs text-slate-500">
            <%= format_kind(@debt.kind) %><%= if @debt.provider, do: " with #{@debt.provider}" %>
          </p>
        </div>
        <div class="flex flex-wrap justify-end gap-2">
          <button type="button" phx-click="open_payment_form" phx-value-id={@debt.id} class="btn btn-secondary btn-xs">
            Record payment
          </button>
          <button type="button" phx-click="archive_debt" phx-value-id={@debt.id} class="btn btn-ghost btn-xs text-rose-600">
            Archive
          </button>
        </div>
      </div>

      <div class="mt-4 grid grid-cols-3 gap-3 text-sm">
        <div>
          <p class="text-[11px] font-semibold uppercase tracking-wide text-slate-400">Balance</p>
          <p class="mt-1 font-semibold text-slate-900"><%= money(@debt.current_balance) %></p>
        </div>
        <div>
          <p class="text-[11px] font-semibold uppercase tracking-wide text-slate-400">Minimum</p>
          <p class="mt-1 font-semibold text-slate-900"><%= money(@debt.minimum_payment) %></p>
        </div>
        <div>
          <p class="text-[11px] font-semibold uppercase tracking-wide text-slate-400">APR</p>
          <p class="mt-1 font-semibold text-slate-900"><%= apr(@debt.apr) %></p>
        </div>
      </div>

      <.form :if={@payment_form_debt_id == @debt.id} for={@payment_form} phx-submit="record_payment" class="mt-4 rounded-lg border border-slate-200 bg-slate-50 p-4">
        <input type="hidden" name="debt_id" value={@debt.id} />
        <div class="grid gap-3 md:grid-cols-2">
          <.finance_input form={@payment_form} field={:amount} label="Payment amount" placeholder="100.00" type="number" step="0.01" />
          <.finance_input form={@payment_form} field={:payment_date} label="Payment date" type="date" />
          <.finance_select form={@payment_form} field={:kind} label="Kind" options={payment_kind_options()} />
          <label class="flex items-center gap-2 rounded-lg border border-slate-200 bg-white px-4 py-3 text-sm font-semibold text-slate-700">
            <input type="hidden" name="payment[create_expense_transaction]" value="false" />
            <input type="checkbox" name="payment[create_expense_transaction]" value="true" checked class="h-4 w-4 rounded border-slate-300 text-slate-900" />
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

      <div :if={@debt.payments != []} class="mt-4 rounded-lg bg-slate-50 p-3">
        <p class="text-[11px] font-semibold uppercase tracking-wide text-slate-400">Recent payments</p>
        <div class="mt-2 space-y-2">
          <div :for={payment <- @debt.payments} class="flex items-center justify-between gap-3 text-sm">
            <span class="text-slate-600">
              <%= format_date(payment.payment_date) %> · <%= format_kind(payment.kind) %>
            </span>
            <span class="font-semibold text-slate-900"><%= money(payment.amount) %></span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp status_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-4 border-b border-slate-100 py-2 last:border-b-0">
      <span class="text-sm text-slate-500"><%= @label %></span>
      <span class="text-sm font-semibold text-slate-900"><%= @value %></span>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :field, :atom, required: true
  attr :label, :string, required: true
  attr :type, :string, default: "text"
  attr :placeholder, :string, default: nil
  attr :step, :string, default: nil

  defp finance_input(assigns) do
    field = assigns.form[assigns.field]
    assigns = assign(assigns, :field_data, field)

    ~H"""
    <div>
      <label for={@field_data.id} class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-slate-500">
        <%= @label %>
      </label>
      <input
        id={@field_data.id}
        name={@field_data.name}
        value={@field_data.value}
        type={@type}
        placeholder={@placeholder}
        step={@step}
        class="w-full rounded-lg border border-slate-200 bg-white px-3 py-2.5 text-sm text-slate-900 outline-none transition focus:border-emerald-400 focus:ring-2 focus:ring-emerald-100"
      />
      <p :for={error <- @field_data.errors} class="mt-1 text-xs text-rose-600"><%= translate_error(error) %></p>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :field, :atom, required: true
  attr :label, :string, required: true
  attr :options, :list, required: true

  defp finance_select(assigns) do
    field = assigns.form[assigns.field]
    assigns = assign(assigns, :field_data, field)

    ~H"""
    <div>
      <label for={@field_data.id} class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-slate-500">
        <%= @label %>
      </label>
      <select
        id={@field_data.id}
        name={@field_data.name}
        class="w-full rounded-lg border border-slate-200 bg-white px-3 py-2.5 text-sm text-slate-900 outline-none transition focus:border-emerald-400 focus:ring-2 focus:ring-emerald-100"
      >
        <option :for={{label, value} <- @options} value={value} selected={selected?(@field_data.value, value)}>
          <%= label %>
        </option>
      </select>
      <p :for={error <- @field_data.errors} class="mt-1 text-xs text-rose-600"><%= translate_error(error) %></p>
    </div>
    """
  end

  attr :plan, :map, required: true

  defp plan_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
      <div class="flex items-start justify-between gap-4">
        <div>
          <p class="text-lg font-semibold text-slate-900"><%= String.capitalize(@plan.strategy) %></p>
          <p class="mt-1 text-xs text-slate-500"><%= if @plan.feasible?, do: "Feasible with current cash flow", else: "Needs more cash flow" %></p>
        </div>
        <button type="button" phx-click="save_plan" phx-value-strategy={@plan.strategy} class="btn btn-secondary btn-xs">
          Save
        </button>
      </div>

      <div class="mt-4 space-y-2">
        <.status_row label="Monthly amount" value={money(@plan.monthly_amount)} />
        <.status_row label="Estimated interest" value={money(@plan.estimated_interest)} />
        <.status_row label="Payoff months" value={to_string(@plan.payoff_months)} />
        <.status_row label="Payoff date" value={format_date(@plan.target_payoff_date)} />
      </div>

      <div class="mt-4 rounded-lg bg-slate-50 p-3">
        <p class="text-[11px] font-semibold uppercase tracking-wide text-slate-400">Order</p>
        <p class="mt-1 text-sm text-slate-700"><%= payoff_order(@plan.payoff_order) %></p>
      </div>
    </div>
    """
  end

  defp assign_finance_data(socket) do
    user = socket.assigns.current_scope.user
    categories = Finance.list_categories_for_user(user)
    budgets = Finance.list_budgets_for_user(user)
    budget_statuses = Enum.map(budgets, &Finance.check_budget_status/1)
    event_budget_statuses = Enum.filter(budget_statuses, &event_budget_status?/1)
    pending_transactions = Finance.list_pending_transactions_for_user(user, limit: 20)
    time_scope = socket.assigns[:time_scope] || "month"
    period_window = period_window(time_scope, event_budget_statuses, Date.utc_today())

    period_summary =
      Finance.get_financial_summary(user, period_window.start_date, period_window.end_date)

    transactions =
      Finance.list_transactions_for_user(user,
        limit: 20,
        status: ["confirmed", "pending_review"],
        start_date: period_window.start_date,
        end_date: period_window.end_date
      )

    confirmed_transactions = Enum.filter(transactions, &(&1.status == "confirmed"))

    assign(socket,
      categories: categories,
      expense_categories: Enum.filter(categories, &(&1.type == "expense")),
      date_window_label: period_window.label,
      period_summary: period_summary,
      transactions: transactions,
      pending_transactions: pending_transactions,
      pending_review_count: length(pending_transactions),
      budget_statuses: budget_statuses,
      event_budget_statuses: event_budget_statuses,
      budget_remaining: budget_remaining(budget_statuses),
      debts: Finance.list_debts_for_user(user),
      health: Finance.get_financial_health(user),
      payment_method_breakdown: payment_method_breakdown(confirmed_transactions),
      plans: Finance.list_payoff_plans_for_user(user)
    )
  end

  defp assign_forms(socket) do
    socket
    |> assign_transaction_form()
    |> assign_category_form()
    |> assign_budget_form()
    |> assign_debt_form()
    |> assign_payment_form()
  end

  defp assign_transaction_form(
         socket,
         transaction \\ %Transaction{
           transaction_date: Date.utc_today(),
           type: "expense",
           source: "manual",
           status: "confirmed"
         }
       ) do
    assign(socket,
      transaction_form: to_form(Finance.change_transaction(transaction), as: :transaction)
    )
  end

  defp assign_category_form(socket) do
    category = %Category{type: "expense", color: "#10B981"}
    assign(socket, category_form: to_form(Finance.change_category(category), as: :category))
  end

  defp assign_budget_form(socket) do
    budget = %Budget{
      period: "monthly",
      start_date: Date.beginning_of_month(Date.utc_today()),
      alert_threshold: 80
    }

    assign(socket, budget_form: to_form(Finance.change_budget(budget), as: :budget))
  end

  defp assign_debt_form(socket) do
    assign(socket, debt_form: to_form(Finance.change_debt(), as: :debt))
  end

  defp assign_payment_form(socket) do
    payment = %DebtPayment{payment_date: Date.utc_today(), kind: "extra"}
    assign(socket, payment_form: to_form(Finance.change_debt_payment(payment), as: :payment))
  end

  defp budget_remaining(statuses) do
    Enum.reduce(statuses, Decimal.new("0"), fn status, total ->
      Decimal.add(total, status.remaining)
    end)
  end

  defp transaction_type_options, do: [{"Expense", "expense"}, {"Income", "income"}]

  defp payment_method_options do
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

  defp budget_period_options do
    [
      {"Monthly", "monthly"},
      {"Weekly", "weekly"},
      {"Daily", "daily"},
      {"Quarterly", "quarterly"},
      {"Yearly", "yearly"},
      {"Custom", "custom"}
    ]
  end

  defp category_options(categories) do
    [{"Uncategorized", ""}] ++ Enum.map(categories, &{&1.name, &1.id})
  end

  defp debt_kind_options do
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

  defp payment_kind_options do
    [
      {"Extra", "extra"},
      {"Minimum", "minimum"},
      {"Settlement", "settlement"},
      {"Adjustment", "adjustment"}
    ]
  end

  defp transaction_form_title(nil), do: "Add transaction"
  defp transaction_form_title(_id), do: "Edit transaction"

  defp transaction_submit(nil), do: "create_transaction"
  defp transaction_submit(_id), do: "update_transaction"

  defp transaction_submit_label(nil, _status), do: "Save transaction"
  defp transaction_submit_label(_id, "pending_review"), do: "Save and confirm"
  defp transaction_submit_label(_id, _status), do: "Save changes"

  defp money(%Decimal{} = amount), do: "$#{Decimal.round(amount, 2)}"
  defp money(nil), do: "$0.00"

  defp signed_money(%Transaction{type: "income", amount: amount}), do: "+#{money(amount)}"
  defp signed_money(%Transaction{amount: amount}), do: "-#{money(amount)}"

  defp apr(nil), do: "Missing"
  defp apr(%Decimal{} = value), do: "#{Decimal.round(value, 2)}%"

  defp selected?(nil, ""), do: true
  defp selected?(value, option), do: to_string(value || "") == option

  defp format_date(nil), do: "Not set"
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%b %-d, %Y")

  defp format_kind(nil), do: "Not set"
  defp format_kind(kind), do: kind |> String.replace("_", " ") |> String.capitalize()

  defp category_name(nil), do: "All spending"
  defp category_name(category), do: category.name

  defp payoff_order([]), do: "No active balances"
  defp payoff_order(debts), do: debts |> Enum.map(& &1.name) |> Enum.join(" -> ")

  defp metric_tone_class("income"), do: "text-emerald-700"
  defp metric_tone_class("expense"), do: "text-rose-700"
  defp metric_tone_class("budget"), do: "text-sky-700"
  defp metric_tone_class("debt"), do: "text-slate-950"
  defp metric_tone_class("review"), do: "text-amber-700"
  defp metric_tone_class("cash"), do: "text-slate-950"
  defp metric_tone_class(_tone), do: "text-slate-950"

  defp transaction_type_class("income"), do: "text-emerald-700"
  defp transaction_type_class(_type), do: "text-rose-700"

  defp transaction_status_label("pending_review"), do: "Pending"
  defp transaction_status_label("ignored"), do: "Ignored"
  defp transaction_status_label(_status), do: "Confirmed"

  defp transaction_status_class("pending_review"), do: "bg-amber-100 text-amber-800"
  defp transaction_status_class("ignored"), do: "bg-slate-200 text-slate-700"
  defp transaction_status_class(_status), do: "bg-emerald-100 text-emerald-700"

  defp show_status_badge?(%Transaction{status: "confirmed"}), do: false
  defp show_status_badge?(_transaction), do: true

  defp review_title(%Transaction{description: description})
       when is_binary(description) and description != "",
       do: description

  defp review_title(%Transaction{merchant: merchant}) when is_binary(merchant) and merchant != "",
    do: merchant

  defp review_title(_transaction), do: "Imported transaction"

  defp source_label(nil), do: "Manual"
  defp source_label(source), do: format_kind(source)

  defp confidence_label(confidence), do: "#{round(confidence * 100)}% confidence"

  defp confidence_class(confidence) when confidence >= 0.85, do: "bg-emerald-100 text-emerald-700"
  defp confidence_class(confidence) when confidence >= 0.6, do: "bg-amber-100 text-amber-800"
  defp confidence_class(_confidence), do: "bg-rose-100 text-rose-700"

  defp review_section_label(0), do: "Review"
  defp review_section_label(count), do: "Review (#{count})"

  defp edit_transaction_section(_transaction), do: "transactions"

  defp budget_state_label(%{is_over: true}), do: "Over"
  defp budget_state_label(%{is_near_limit: true}), do: "Near limit"
  defp budget_state_label(_status), do: "On track"

  defp budget_state_class(%{is_over: true}), do: "bg-rose-100 text-rose-700"
  defp budget_state_class(%{is_near_limit: true}), do: "bg-amber-100 text-amber-800"
  defp budget_state_class(_status), do: "bg-emerald-100 text-emerald-700"

  defp budget_progress_class(%{is_over: true}), do: "bg-rose-500"
  defp budget_progress_class(%{is_near_limit: true}), do: "bg-amber-500"
  defp budget_progress_class(_status), do: "bg-emerald-500"

  defp admin_user?(%{user: %{role: "admin"}}), do: true
  defp admin_user?(_scope), do: false

  defp finance_title("personal", %{user: user}) do
    cond do
      is_binary(user.full_name) and user.full_name != "" -> "#{user.full_name}'s account"
      is_binary(user.username) and user.username != "" -> "@#{user.username}'s account"
      true -> "Personal account"
    end
  end

  defp finance_title(_, _scope), do: "Finance command center"

  defp time_scope_title("day"), do: "Day"
  defp time_scope_title("week"), do: "Week"
  defp time_scope_title("month"), do: "Month"
  defp time_scope_title("year"), do: "Year"
  defp time_scope_title("event"), do: "Event"

  defp time_scope_summary_note("event", label), do: "Focused on #{label}"
  defp time_scope_summary_note(scope, label), do: "#{time_scope_title(scope)} view · #{label}"

  defp period_window("day", _event_budget_statuses, today) do
    %{start_date: today, end_date: today, label: format_period_window(today, today)}
  end

  defp period_window("week", _event_budget_statuses, today) do
    start_date = Date.beginning_of_week(today)
    end_date = Date.add(start_date, 6)

    %{
      start_date: start_date,
      end_date: end_date,
      label: format_period_window(start_date, end_date)
    }
  end

  defp period_window("month", _event_budget_statuses, today) do
    start_date = Date.beginning_of_month(today)
    end_date = Date.end_of_month(today)

    %{
      start_date: start_date,
      end_date: end_date,
      label: format_period_window(start_date, end_date)
    }
  end

  defp period_window("year", _event_budget_statuses, today) do
    start_date = Date.new!(today.year, 1, 1)
    end_date = Date.new!(today.year, 12, 31)

    %{
      start_date: start_date,
      end_date: end_date,
      label: format_period_window(start_date, end_date)
    }
  end

  defp period_window("event", [status | _rest], _today) do
    end_date = status.budget.end_date || status.budget.start_date

    %{
      start_date: status.budget.start_date,
      end_date: end_date,
      label: status.budget.name
    }
  end

  defp period_window("event", [], today) do
    start_date = Date.beginning_of_month(today)
    end_date = Date.end_of_month(today)

    %{
      start_date: start_date,
      end_date: end_date,
      label: "No event budget selected"
    }
  end

  defp event_budget_status?(%{budget: %{period: "custom", end_date: end_date}})
       when not is_nil(end_date),
       do: true

  defp event_budget_status?(_status), do: false

  defp payment_method_breakdown(transactions) do
    transactions
    |> Enum.group_by(&payment_method_label(&1.payment_method))
    |> Enum.map(fn {label, grouped_transactions} ->
      %{
        label: label,
        count: length(grouped_transactions),
        amount:
          Enum.reduce(grouped_transactions, Decimal.new("0"), fn transaction, total ->
            Decimal.add(total, transaction.amount)
          end)
      }
    end)
    |> Enum.sort_by(&{Decimal.to_float(&1.amount) * -1, &1.label})
  end

  defp payment_method_label(nil), do: "Unspecified"
  defp payment_method_label(""), do: "Unspecified"
  defp payment_method_label(method), do: format_kind(method)

  defp due_day_label(nil), do: "Due day not set"
  defp due_day_label(due_day), do: "Due on day #{due_day}"

  defp format_period_window(start_date, end_date) do
    "#{format_date(start_date)} to #{format_date(end_date)}"
  end

  defp focus_panel_title("budget_overview"), do: "Budget overview"
  defp focus_panel_title("activity"), do: "Recent activity"
  defp focus_panel_title("signals"), do: "Signals and visibility"
  defp focus_panel_title("obligations"), do: "Obligations and payoff plans"

  defp translate_error({message, opts}) do
    Enum.reduce(opts, message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end

defmodule CoreWeb.FinanceLive do
  use CoreWeb, :live_view

  import CoreWeb.FinanceComponents

  alias Core.Accounts
  alias Core.Finance
  alias Core.Finance.{Account, Budget, Category, Debt, DebtPayment, SavingsGoal, Transaction}

  @default_currency "DOP"
  @sections [
    "overview",
    "networth",
    "accounts",
    "transactions",
    "review",
    "budgets",
    "debts",
    "goals",
    "insights"
  ]
  @time_scopes ["day", "week", "month", "year", "event"]
  @focus_panels [
    "budget_overview",
    "activity",
    "signals",
    "obligations",
    "transaction",
    "budget",
    "debt",
    "household"
  ]

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:current_scope, fn -> nil end)
     |> assign(
       page_title: "Finance",
       active_section: "overview",
       ownership_scope: "personal",
       time_scope: "month",
       net_worth_filter: "all",
       households: [],
       selected_household_id: nil,
       selected_household: nil,
       household_panel_open: false,
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

  def handle_event("filter_net_worth", %{"category" => category}, socket) do
    {:noreply, assign(socket, :net_worth_filter, category)}
  end

  def handle_event("set_time_scope", %{"scope" => scope}, socket) when scope in @time_scopes do
    {:noreply, socket |> assign(time_scope: scope) |> assign_finance_data()}
  end

  def handle_event("set_time_scope", _params, socket), do: {:noreply, socket}

  def handle_event("set_ownership_scope", %{"scope" => "personal"}, socket) do
    {:noreply,
     socket
     |> close_action_surface()
     |> assign(ownership_scope: "personal")
     |> assign_finance_data()}
  end

  def handle_event("set_ownership_scope", %{"scope" => "household"}, socket) do
    households = socket.assigns.households
    selected_household = select_household(households, socket.assigns.selected_household_id)

    if selected_household do
      {:noreply,
       socket
       |> close_action_surface()
       |> assign(
         ownership_scope: "household",
         selected_household_id: selected_household.id,
         selected_household: selected_household
       )
       |> assign_finance_data()}
    else
      {:noreply, socket}
    end
  end

  def handle_event("set_ownership_scope", _params, socket), do: {:noreply, socket}

  def handle_event("open_focus_panel", %{"panel" => panel}, socket)
      when panel in @focus_panels do
    {:noreply, prepare_focus_panel(socket, panel)}
  end

  def handle_event("open_focus_panel", _params, socket), do: {:noreply, socket}

  def handle_event("close_focus_panel", _params, socket) do
    {:noreply,
     socket
     |> close_action_surface()
     |> assign_transaction_form()
     |> assign_budget_form()
     |> assign_debt_form()
     |> assign_goal_form()}
  end

  def handle_event("open_household_panel", _params, socket) do
    {:noreply, open_action_surface(socket, "household")}
  end

  def handle_event("close_household_panel", _params, socket) do
    {:noreply, close_action_surface(socket)}
  end

  def handle_event("select_household", %{"household_id" => household_id}, socket) do
    selected_household = select_household(socket.assigns.households, household_id)

    {:noreply,
     socket
     |> assign(
       ownership_scope:
         resolved_ownership_scope(socket.assigns.ownership_scope, selected_household),
       selected_household_id: selected_household && selected_household.id,
       selected_household: selected_household
     )
     |> assign_finance_data()}
  end

  def handle_event("create_household", %{"household" => params}, socket) do
    user = current_actor(socket)

    case Accounts.create_household(user, params) do
      {:ok, household} ->
        {:noreply,
         socket
         |> put_flash(:info, "Household created")
         |> assign(ownership_scope: "household", selected_household_id: household.id)
         |> close_action_surface()
         |> assign_household_form()
         |> assign_finance_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> open_action_surface("household")
         |> assign(household_form: to_form(changeset, as: :household))}
    end
  end

  def handle_event("add_household_member", %{"member_invite" => %{"email" => email}}, socket) do
    user = current_actor(socket)
    household = socket.assigns.selected_household

    case Accounts.add_household_member_by_email(user, household, email) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> put_flash(:info, "Member added")
         |> open_action_surface("household")
         |> assign_member_form()
         |> assign_finance_data()}

      {:error, :user_not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "User not found")
         |> open_action_surface("household")}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "Only household owners can add members")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> open_action_surface("household")
         |> assign(member_form: to_form(changeset, as: :member_invite))}
    end
  end

  def handle_event("create_transaction", %{"transaction" => params}, socket) do
    user = current_actor(socket)
    owner = current_finance_owner(socket)

    case Finance.create_transaction(user, owner, params) do
      {:ok, _transaction} ->
        {:noreply,
         socket
         |> put_flash(:info, "Transaction added")
         |> close_action_surface()
         |> assign(editing_transaction_id: nil)
         |> assign_transaction_form()
         |> assign_finance_data()}

      {:error, :invalid_category_scope} ->
        {:noreply, put_flash(socket, :error, "Choose a category from the active scope")}

      {:error, :invalid_account_scope} ->
        {:noreply, put_flash(socket, :error, "Choose an account from the active scope")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> open_action_surface("transaction")
         |> assign(transaction_form: to_form(changeset, as: :transaction))}
    end
  end

  def handle_event("open_edit_transaction", %{"id" => id}, socket) do
    user = current_actor(socket)
    owner = current_finance_owner(socket)
    transaction = Finance.get_transaction!(user, owner, id)

    {:noreply,
     socket
     |> open_action_surface("transaction")
     |> assign(editing_transaction_id: transaction.id)
     |> assign_transaction_form(transaction)}
  end

  def handle_event("cancel_transaction_edit", _params, socket) do
    {:noreply,
     socket
     |> close_action_surface()
     |> assign(editing_transaction_id: nil)
     |> assign_transaction_form()}
  end

  def handle_event("update_transaction", %{"transaction" => params}, socket) do
    user = current_actor(socket)
    owner = current_finance_owner(socket)
    transaction = Finance.get_transaction!(user, owner, socket.assigns.editing_transaction_id)

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
         |> close_action_surface()
         |> assign(active_section: "transactions")
         |> assign(editing_transaction_id: nil)
         |> assign_transaction_form()
         |> assign_finance_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> open_action_surface("transaction")
         |> assign(transaction_form: to_form(changeset, as: :transaction))}

      {:error, :invalid_category_scope} ->
        {:noreply, put_flash(socket, :error, "Choose a category from the active scope")}

      {:error, :invalid_account_scope} ->
        {:noreply, put_flash(socket, :error, "Choose an account from the active scope")}
    end
  end

  def handle_event("create_account", %{"account" => params}, socket) do
    user = current_actor(socket)
    owner = current_finance_owner(socket)

    case Finance.create_account(user, owner, params) do
      {:ok, _account} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account added")
         |> close_action_surface()
         |> assign_account_form()
         |> assign_finance_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> open_action_surface("accounts")
         |> assign(account_form: to_form(changeset, as: :account))}
    end
  end

  def handle_event("delete_transaction", %{"id" => id}, socket) do
    user = current_actor(socket)
    owner = current_finance_owner(socket)
    transaction = Finance.get_transaction!(user, owner, id)

    case Finance.delete_transaction(user, transaction) do
      {:ok, _transaction} ->
        {:noreply, socket |> put_flash(:info, "Transaction deleted") |> assign_finance_data()}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Transaction could not be deleted")}
    end
  end

  def handle_event("confirm_transaction", %{"id" => id}, socket) do
    user = current_actor(socket)
    owner = current_finance_owner(socket)
    transaction = Finance.get_transaction!(user, owner, id)

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
    user = current_actor(socket)
    owner = current_finance_owner(socket)
    transaction = Finance.get_transaction!(user, owner, id)

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
    user = current_actor(socket)
    owner = current_finance_owner(socket)

    case Finance.create_category(user, owner, params) do
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
    user = current_actor(socket)
    owner = current_finance_owner(socket)

    case Finance.create_budget(user, owner, params) do
      {:ok, _budget} ->
        {:noreply,
         socket
         |> put_flash(:info, "Budget added")
         |> close_action_surface()
         |> assign_budget_form()
         |> assign_finance_data()}

      {:error, :invalid_category_scope} ->
        {:noreply, put_flash(socket, :error, "Choose a category from the active scope")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> open_action_surface("budget")
         |> assign(budget_form: to_form(changeset, as: :budget))}
    end
  end

  def handle_event("open_debt_form", _params, socket) do
    {:noreply, open_action_surface(socket, "debt")}
  end

  def handle_event("close_debt_form", _params, socket) do
    {:noreply, socket |> close_action_surface() |> assign_debt_form()}
  end

  def handle_event("create_debt", %{"debt" => params}, socket) do
    user = current_actor(socket)
    owner = current_finance_owner(socket)

    case Finance.create_debt(user, owner, params) do
      {:ok, _debt} ->
        {:noreply,
         socket
         |> put_flash(:info, "Debt added")
         |> close_action_surface()
         |> assign_debt_form()
         |> assign_payment_form()
         |> assign_finance_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> open_action_surface("debt")
         |> assign(debt_form: to_form(changeset, as: :debt))}
    end
  end

  def handle_event("create_goal", %{"goal" => params}, socket) do
    user = current_actor(socket)
    owner = current_finance_owner(socket)

    case Finance.create_savings_goal(user, owner, params) do
      {:ok, _goal} ->
        {:noreply,
         socket
         |> put_flash(:info, "Savings goal added")
         |> close_action_surface()
         |> assign_goal_form()
         |> assign_finance_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> open_action_surface("goal")
         |> assign(goal_form: to_form(changeset, as: :goal))}
    end
  end

  def handle_event("archive_goal", %{"id" => id}, socket) do
    user = current_actor(socket)
    owner = current_finance_owner(socket)
    goal = Finance.get_savings_goal!(user, owner, id)

    case Finance.delete_savings_goal(user, goal) do
      {:ok, _goal} ->
        {:noreply, socket |> put_flash(:info, "Savings goal archived") |> assign_finance_data()}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Savings goal could not be archived")}
    end
  end

  def handle_event("open_payment_form", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(payment_form_debt_id: id, debt_form_open: false)
     |> assign_payment_form()}
  end

  def handle_event("close_payment_form", _params, socket) do
    {:noreply, socket |> assign(payment_form_debt_id: nil) |> assign_payment_form()}
  end

  def handle_event("record_payment", %{"payment" => params, "debt_id" => debt_id}, socket) do
    user = current_actor(socket)
    owner = current_finance_owner(socket)
    debt = Finance.get_debt!(user, owner, debt_id)

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
         |> assign(payment_form_debt_id: debt_id)
         |> assign(payment_form: to_form(changeset, as: :payment))}
    end
  end

  def handle_event("archive_debt", %{"id" => id}, socket) do
    user = current_actor(socket)
    owner = current_finance_owner(socket)
    debt = Finance.get_debt!(user, owner, id)

    case Finance.delete_debt(user, debt) do
      {:ok, _debt} ->
        {:noreply, socket |> put_flash(:info, "Debt archived") |> assign_finance_data()}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Debt could not be archived")}
    end
  end

  def handle_event("generate_plans", _params, socket) do
    user = current_actor(socket)
    owner = current_finance_owner(socket)
    comparison = Finance.generate_debt_payoff_comparison(user, owner, [])
    {:noreply, assign(socket, comparison: comparison, active_section: "debts")}
  end

  def handle_event("save_plan", %{"strategy" => strategy}, socket) do
    user = current_actor(socket)
    owner = current_finance_owner(socket)
    plan = Enum.find(socket.assigns.comparison, &(&1.strategy == strategy))

    result =
      if plan do
        Finance.save_generated_debt_payoff_plan(user, owner, plan)
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
      <div class="finance-shell min-h-screen">
        <div class="mx-auto grid min-h-screen max-w-[118rem] gap-6 px-4 py-6 sm:px-6 xl:grid-cols-[17rem_minmax(0,1fr)] xl:px-8">
          <aside class="hidden xl:flex xl:flex-col xl:gap-6">
            <.glass class="flex min-h-[calc(100vh-3rem)] flex-col" glow="linear-gradient(160deg, rgba(155,140,255,0.25), rgba(111,207,151,0.15))">
              <div class="flex h-full flex-col px-5 py-6">
                <div class="flex items-center gap-3">
                  <div class="flex h-11 w-11 items-center justify-center rounded-2xl bg-gradient-to-br from-[#9B8CFF] via-[#7c6cf0] to-[#6FCF97] text-base font-semibold text-white">
                    IZ
                  </div>
                  <div>
                    <p class="font-display text-lg tracking-tight text-white">IziHub Finance</p>
                    <p class="text-xs uppercase tracking-[0.24em] text-slate-400">Dashboard</p>
                  </div>
                </div>

                <nav class="mt-8 space-y-1.5 text-sm">
                  <.side_nav_button active_section={@active_section} section="overview" label="Overview" icon="hero-home" />
                  <.side_nav_button active_section={@active_section} section="networth" label="Net worth" icon="hero-arrow-trending-up" />
                  <.side_nav_button active_section={@active_section} section="accounts" label="Accounts" icon="hero-lock-closed" />
                  <.side_nav_button active_section={@active_section} section="transactions" label="Transactions" icon="hero-building-library" />
                  <.side_nav_button active_section={@active_section} section="review" label={review_section_label(@pending_review_count)} icon="hero-shield-check" />
                  <.side_nav_button active_section={@active_section} section="budgets" label="Budgets" icon="hero-chart-bar-square" />
                  <.side_nav_button active_section={@active_section} section="debts" label="Debts" icon="hero-banknotes" />
                  <.side_nav_button active_section={@active_section} section="goals" label="Goals" icon="hero-check" />
                  <.side_nav_button active_section={@active_section} section="insights" label="Insights" icon="hero-wrench-screwdriver" />
                </nav>

                <div class="mt-auto flex items-center gap-3 border-t border-white/10 pt-5">
                  <div class="flex h-11 w-11 items-center justify-center rounded-full bg-[var(--tone-income)] text-sm font-semibold text-[#0A0D12]">
                    <%= initials(@current_scope.user) %>
                  </div>
                  <div class="min-w-0">
                    <p class="truncate text-sm font-semibold text-white"><%= current_scope_name(@current_scope.user) %></p>
                    <p class="truncate text-xs text-slate-400"><%= if @ownership_scope == "household" and @selected_household, do: @selected_household.name, else: "Personal scope" %></p>
                  </div>
                </div>
              </div>
            </.glass>
          </aside>

          <div class="min-w-0 space-y-6 lg:max-w-[92rem]">
            <.finance_dashboard_header :if={@active_section == "overview"} {assigns} />
            <.finance_section_header :if={@active_section != "overview"} {assigns} />

            <nav class="flex gap-2 overflow-x-auto pb-1 xl:hidden">
              <.section_button active_section={@active_section} section="overview" label="Overview" />
              <.section_button active_section={@active_section} section="networth" label="Net worth" />
              <.section_button active_section={@active_section} section="accounts" label="Accounts" />
              <.section_button active_section={@active_section} section="transactions" label="Transactions" />
              <.section_button active_section={@active_section} section="review" label={review_section_label(@pending_review_count)} />
              <.section_button active_section={@active_section} section="budgets" label="Budgets" />
              <.section_button active_section={@active_section} section="debts" label="Debts" />
              <.section_button active_section={@active_section} section="goals" label="Goals" />
              <.section_button active_section={@active_section} section="insights" label="Insights" />
            </nav>

            <div>
              <.overview_section :if={@active_section == "overview"} {assigns} />
              <.networth_section :if={@active_section == "networth"} {assigns} />
              <.accounts_panel :if={@active_section == "accounts"} {assigns} />
              <.transactions_section :if={@active_section == "transactions"} {assigns} />
              <.review_section :if={@active_section == "review"} {assigns} />
              <.budgets_section :if={@active_section == "budgets"} {assigns} />
              <.debts_section :if={@active_section == "debts"} {assigns} />
              <.goal_panel :if={@active_section == "goals"} {assigns} />
              <.insights_section :if={@active_section == "insights"} {assigns} />
            </div>
          </div>

          <.focus_panel_modal :if={@focus_panel} panel={@focus_panel} {assigns} />
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp assign_finance_data(socket) do
    user = current_actor(socket)
    today = Date.utc_today()
    households = Accounts.list_households_for_user(user)
    selected_household = select_household(households, socket.assigns[:selected_household_id])

    ownership_scope =
      resolved_ownership_scope(socket.assigns[:ownership_scope], selected_household)

    time_scope = socket.assigns[:time_scope] || "month"
    owner = finance_owner(ownership_scope, user, selected_household)

    {:ok, categories} = Finance.list_categories(user, owner)
    {:ok, accounts} = Finance.list_accounts(user, owner)
    {:ok, budgets} = Finance.list_budgets(user, owner)
    budget_statuses = Enum.map(budgets, &Finance.check_budget_status/1)
    event_budget_statuses = Enum.filter(budget_statuses, &event_budget_status?/1)
    {:ok, pending_transactions} = Finance.list_pending_transactions(user, owner, limit: 20)
    period_window = period_window(time_scope, event_budget_statuses, today)

    {:ok, account_summaries} =
      Finance.list_account_summaries(
        user,
        owner,
        period_window.start_date,
        period_window.end_date
      )

    period_summary =
      Finance.get_financial_summary(owner, period_window.start_date, period_window.end_date)

    period_summary_totals =
      Finance.get_currency_summary(owner, period_window.start_date, period_window.end_date)

    {:ok, transactions} =
      Finance.list_transactions(user, owner,
        limit: 20,
        status: ["confirmed", "pending_review"],
        start_date: period_window.start_date,
        end_date: period_window.end_date
      )

    # Overview's recent-activity feed is intentionally independent of the
    # Transactions page's date-range picker — it always shows the latest
    # confirmed/pending activity so the dashboard stays "up to date" by
    # default, regardless of whatever range someone last picked elsewhere.
    {:ok, recent_transactions} =
      Finance.list_transactions(user, owner, limit: 6, status: ["confirmed", "pending_review"])

    confirmed_transactions = Enum.filter(transactions, &(&1.status == "confirmed"))
    {:ok, debts} = Finance.list_debts(user, owner)
    {:ok, plans} = Finance.list_payoff_plans(user, owner)
    {:ok, savings_goals} = Finance.list_savings_goals(user, owner)
    health = Finance.get_financial_health(user, owner, today: today)

    current_month_summary_totals =
      Finance.get_currency_summary(
        owner,
        Date.beginning_of_month(today),
        Date.end_of_month(today),
        exclude_debt_payment_expenses: true
      )

    account_total_balance_totals = currency_totals(accounts, & &1.current_balance, & &1.currency)

    budget_remaining_totals =
      currency_totals(budget_statuses, & &1.remaining, & &1.budget.currency)

    budget_spent_totals = currency_totals(budget_statuses, & &1.spent, & &1.budget.currency)
    budget_usage_pct = average_budget_usage(budget_statuses)

    debt_total_totals = currency_totals(debts, & &1.current_balance, & &1.currency)
    minimum_debt_payment_totals = currency_totals(debts, & &1.minimum_payment, & &1.currency)
    debt_currencies = currency_codes(debts, & &1.currency)

    net_worth_items = net_worth_items(accounts, debts)
    net_worth_groups = net_worth_groups(net_worth_items)
    net_worth_currencies = currency_codes(net_worth_items, & &1.currency)

    cashflow_months = cashflow_months(owner, today)
    spending_breakdown = category_spending_breakdown(user, owner, today)

    base_assigns = %{
      households: households,
      ownership_scope: ownership_scope,
      selected_household_id: selected_household && selected_household.id,
      selected_household: selected_household,
      household_panel_open: socket.assigns[:household_panel_open] || false
    }

    assign(
      socket,
      Map.merge(base_assigns, %{
        categories: categories,
        accounts: accounts,
        account_summaries: account_summaries,
        account_total_balance: account_total_balance(accounts),
        account_total_balance_totals: account_total_balance_totals,
        expense_categories: Enum.filter(categories, &(&1.type == "expense")),
        date_window_label: period_window.label,
        period_summary: period_summary,
        period_summary_totals: period_summary_totals,
        current_month_summary_totals: current_month_summary_totals,
        transactions: transactions,
        recent_transactions: recent_transactions,
        pending_transactions: pending_transactions,
        pending_review_count: length(pending_transactions),
        budget_statuses: budget_statuses,
        event_budget_statuses: event_budget_statuses,
        budget_remaining: budget_remaining(budget_statuses),
        budget_remaining_totals: budget_remaining_totals,
        budget_spent_totals: budget_spent_totals,
        budget_usage_pct: budget_usage_pct,
        debts: debts,
        debt_total_totals: debt_total_totals,
        minimum_debt_payment_totals: minimum_debt_payment_totals,
        debt_currencies: debt_currencies,
        savings_goals: savings_goals,
        net_worth_items: net_worth_items,
        net_worth_groups: net_worth_groups,
        net_worth_summary: net_worth_summary(net_worth_items),
        net_worth_allocation: net_worth_allocation(net_worth_groups, net_worth_currencies),
        cashflow_months: cashflow_months,
        spending_breakdown: spending_breakdown,
        health: health,
        payment_method_breakdown: payment_method_breakdown(confirmed_transactions),
        plans: plans
      })
    )
  end

  defp assign_forms(socket) do
    socket
    |> assign_transaction_form()
    |> assign_category_form()
    |> assign_budget_form()
    |> assign_debt_form()
    |> assign_payment_form()
    |> assign_account_form()
    |> assign_goal_form()
    |> assign_household_form()
    |> assign_member_form()
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
      currency: @default_currency,
      period: "monthly",
      start_date: Date.beginning_of_month(Date.utc_today()),
      alert_threshold: 80
    }

    assign(socket, budget_form: to_form(Finance.change_budget(budget), as: :budget))
  end

  defp assign_debt_form(socket) do
    debt = %Debt{currency: @default_currency}
    assign(socket, debt_form: to_form(Finance.change_debt(debt), as: :debt))
  end

  defp assign_payment_form(socket) do
    payment = %DebtPayment{payment_date: Date.utc_today(), kind: "extra"}
    assign(socket, payment_form: to_form(Finance.change_debt_payment(payment), as: :payment))
  end

  defp assign_account_form(socket) do
    account = %Account{
      kind: "checking",
      currency: @default_currency,
      current_balance: Decimal.new("0")
    }

    assign(socket, account_form: to_form(Finance.change_account(account), as: :account))
  end

  defp assign_goal_form(socket) do
    goal = %SavingsGoal{currency: @default_currency, saved_amount: Decimal.new("0")}
    assign(socket, goal_form: to_form(Finance.change_savings_goal(goal), as: :goal))
  end

  defp assign_household_form(socket) do
    assign(socket, household_form: to_form(Accounts.change_household(), as: :household))
  end

  defp assign_member_form(socket) do
    assign(socket, member_form: to_form(%{"email" => ""}, as: :member_invite))
  end

  defp prepare_focus_panel(socket, "transaction") do
    socket
    |> assign(editing_transaction_id: nil)
    |> assign_transaction_form()
    |> open_action_surface("transaction")
  end

  defp prepare_focus_panel(socket, "budget") do
    socket
    |> assign_budget_form()
    |> open_action_surface("budget")
  end

  defp prepare_focus_panel(socket, "debt") do
    socket
    |> assign_debt_form()
    |> open_action_surface("debt")
  end

  defp prepare_focus_panel(socket, "household") do
    socket
    |> assign_household_form()
    |> assign_member_form()
    |> open_action_surface("household")
  end

  defp prepare_focus_panel(socket, panel), do: open_action_surface(socket, panel)

  defp open_action_surface(socket, panel) when is_binary(panel) do
    socket
    |> assign(
      focus_panel: panel,
      household_panel_open: panel == "household",
      debt_form_open: panel == "debt"
    )
  end

  defp close_action_surface(socket) do
    socket
    |> assign(
      focus_panel: nil,
      household_panel_open: false,
      debt_form_open: false,
      editing_transaction_id: nil
    )
  end

  defp budget_remaining(statuses) do
    Enum.reduce(statuses, Decimal.new("0"), fn status, total ->
      Decimal.add(total, status.remaining)
    end)
  end

  defp average_budget_usage([]), do: 0.0

  defp average_budget_usage(statuses) do
    statuses
    |> Enum.map(& &1.percentage)
    |> Enum.sum()
    |> Kernel./(length(statuses))
  end

  defp resolved_ownership_scope("household", nil), do: "personal"

  defp resolved_ownership_scope(scope, _selected_household)
       when scope in ["personal", "household"],
       do: scope

  defp resolved_ownership_scope(_scope, _selected_household), do: "personal"

  defp select_household([], _selected_household_id), do: nil
  defp select_household(households, nil), do: List.first(households)

  defp select_household(households, selected_household_id) do
    Enum.find(households, &(&1.id == selected_household_id)) || List.first(households)
  end

  defp finance_owner("household", _user, %{} = household), do: household
  defp finance_owner(_scope, user, _household), do: user

  defp current_actor(socket), do: socket.assigns.current_scope.user

  defp current_finance_owner(socket),
    do:
      finance_owner(
        socket.assigns.ownership_scope,
        current_actor(socket),
        socket.assigns.selected_household
      )

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

  defp account_total_balance(accounts) do
    Enum.reduce(accounts, Decimal.new("0"), fn account, total ->
      Decimal.add(total, account.current_balance || Decimal.new("0"))
    end)
  end

  # --- net worth ------------------------------------------------------------
  #
  # Net worth combines two existing schemas (Account and Debt) instead of
  # introducing a new one. Accounts of kind "credit_card" or "loan" are
  # treated as liabilities (their balance is stored as a magnitude, not
  # necessarily signed), everything else is an asset. Debt records are
  # always liabilities. Every item's `amount` is normalized so assets are
  # positive and liabilities are negative — that way a single
  # `currency_totals/3` call over the combined list yields the net figure.

  defp net_worth_account_category(%{kind: kind}) when kind in ["checking", "savings", "cash"],
    do: "cash"

  defp net_worth_account_category(%{kind: "investment"}), do: "investments"

  defp net_worth_account_category(%{kind: kind}) when kind in ["credit_card", "loan"],
    do: "liabilities"

  defp net_worth_account_category(_account), do: "other_assets"

  defp net_worth_items(accounts, debts) do
    account_items =
      Enum.map(accounts, fn account ->
        category = net_worth_account_category(account)
        balance = account.current_balance || Decimal.new("0")

        amount =
          if category == "liabilities", do: balance |> Decimal.abs() |> Decimal.negate(), else: balance

        %{
          id: "account-#{account.id}",
          name: account.name,
          subtitle: format_kind(account.kind),
          category: category,
          currency: normalize_currency(account.currency),
          amount: amount
        }
      end)

    debt_items =
      Enum.map(debts, fn debt ->
        %{
          id: "debt-#{debt.id}",
          name: debt.name,
          subtitle: format_kind(debt.kind),
          category: "liabilities",
          currency: normalize_currency(debt.currency),
          amount: Decimal.negate(debt.current_balance || Decimal.new("0"))
        }
      end)

    (account_items ++ debt_items)
    |> Enum.sort_by(fn item ->
      category_rank =
        Enum.find_index(networth_category_order(), &(&1 == item.category)) ||
          length(networth_category_order())

      {category_rank, -abs(decimal_to_float(item.amount))}
    end)
  end

  defp net_worth_groups(items) do
    Enum.map(networth_category_order(), fn category ->
      category_items = Enum.filter(items, &(&1.category == category))
      meta = networth_category_meta(category)

      %{
        key: category,
        label: meta.label,
        tone: meta.tone,
        items: category_items,
        totals:
          category_items
          |> currency_totals(& &1.amount, & &1.currency)
          |> Enum.map(&%{&1 | amount: Decimal.abs(&1.amount)})
      }
    end)
  end

  defp net_worth_summary(items) do
    {liabilities, assets} = Enum.split_with(items, &(&1.category == "liabilities"))

    %{
      net: currency_totals(items, & &1.amount, & &1.currency),
      assets: currency_totals(assets, & &1.amount, & &1.currency),
      liabilities:
        liabilities
        |> currency_totals(& &1.amount, & &1.currency)
        |> Enum.map(&%{&1 | amount: Decimal.abs(&1.amount)})
    }
  end

  defp net_worth_allocation(groups, currencies) do
    Enum.map(currencies, fn currency ->
      segments =
        Enum.map(groups, fn group ->
          amount =
            case Enum.find(group.totals, &(&1.currency == currency)) do
              nil -> Decimal.new("0")
              %{amount: amount} -> amount
            end

          %{key: group.key, tone: group.tone, amount: amount}
        end)

      total = Enum.reduce(segments, Decimal.new("0"), &Decimal.add(&2, &1.amount))

      segments =
        Enum.map(segments, fn segment ->
          pct =
            if Decimal.compare(total, Decimal.new("0")) == :eq do
              0.0
            else
              decimal_to_float(segment.amount) / decimal_to_float(total) * 100
            end

          Map.put(segment, :pct, pct)
        end)

      %{currency: currency, segments: segments, total: total}
    end)
  end

  defp format_period_window(start_date, end_date) do
    "#{format_date(start_date)} to #{format_date(end_date)}"
  end

  # --- cashflow (dashboard heatmap) -----------------------------------------
  #
  # Six calendar months of net flow (income minus expenses), oldest to
  # newest, reusing the same scalar `get_financial_summary/3` the "Net flow"
  # comparison already relies on elsewhere on the dashboard. Currency is not
  # tracked per-month here (consistent with how `period_summary` already
  # collapses currencies) since this is an at-a-glance trend widget, not a
  # precise ledger.

  defp cashflow_months(owner, today) do
    current_month_start = Date.beginning_of_month(today)

    0..5
    |> Enum.map(fn offset ->
      month_start = shift_months(current_month_start, offset - 5)
      month_end = Date.end_of_month(month_start)
      summary = Finance.get_financial_summary(owner, month_start, month_end)

      %{
        label: Calendar.strftime(month_start, "%b"),
        income: summary.income,
        expenses: summary.expenses,
        balance: summary.balance
      }
    end)
    |> with_cashflow_intensity()
  end

  # Only ever called with the first of a month, so the day is always 1.
  defp shift_months(%Date{year: year, month: month}, n) do
    total = year * 12 + (month - 1) + n
    Date.new!(div(total, 12), rem(total, 12) + 1, 1)
  end

  defp with_cashflow_intensity(months) do
    max_amount =
      months
      |> Enum.map(&abs(decimal_to_float(&1.balance)))
      |> Enum.max()
      |> max(1.0)

    Enum.map(months, fn month ->
      intensity = min(100, round(abs(decimal_to_float(month.balance)) / max_amount * 100))
      Map.put(month, :intensity, intensity)
    end)
  end

  # --- spending breakdown (dashboard segmented bar) --------------------------
  #
  # Current month's confirmed expenses grouped by category, for the
  # TailAdmin-inspired "Spending" widget. Amounts are summed as raw Decimals
  # across accounts (same simplification `get_financial_summary/3` already
  # makes) since this is a proportion widget, not a currency-exact total.

  defp category_spending_breakdown(user, owner, today) do
    {:ok, transactions} =
      Finance.list_transactions(user, owner,
        status: ["confirmed"],
        type: "expense",
        start_date: Date.beginning_of_month(today),
        end_date: Date.end_of_month(today)
      )

    total = Enum.reduce(transactions, Decimal.new("0"), &Decimal.add(&2, &1.amount))

    transactions
    |> Enum.group_by(&category_bucket_key/1)
    |> Enum.map(fn {name, grouped} ->
      amount = Enum.reduce(grouped, Decimal.new("0"), &Decimal.add(&2, &1.amount))
      sample = List.first(grouped)

      %{
        name: name,
        color: category_bucket_color(sample),
        amount: amount,
        pct: spending_pct(amount, total)
      }
    end)
    |> Enum.sort_by(&(-decimal_to_float(&1.amount)))
    |> Enum.take(6)
  end

  defp category_bucket_key(%{category: %{name: name}}), do: name
  defp category_bucket_key(_transaction), do: "Uncategorized"

  defp category_bucket_color(%{category: %{color: color}}) when is_binary(color) and color != "",
    do: color

  defp category_bucket_color(_transaction), do: "#64748B"

  defp spending_pct(amount, total) do
    if Decimal.compare(total, Decimal.new("0")) == :gt do
      decimal_to_float(amount) / decimal_to_float(total) * 100
    else
      0.0
    end
  end
end

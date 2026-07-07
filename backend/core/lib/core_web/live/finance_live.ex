defmodule CoreWeb.FinanceLive do
  use CoreWeb, :live_view

  alias Core.Accounts
  alias Core.Finance
  alias Core.Finance.{Account, Budget, Category, DebtPayment, Transaction}

  @sections ["overview", "transactions", "review", "budgets", "debts", "insights"]
  @time_scopes ["day", "week", "month", "year", "event"]
  @focus_panels [
    "budget_overview",
    "activity",
    "signals",
    "obligations",
    "accounts",
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
     |> assign_debt_form()}
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
      <div class="min-h-screen bg-[#f7f2ff] text-slate-900">
        <div class="mx-auto grid min-h-screen max-w-[118rem] gap-6 px-4 py-6 sm:px-6 xl:grid-cols-[17rem_minmax(0,1fr)] xl:px-8">
          <aside class="hidden xl:flex xl:flex-col xl:gap-6">
            <div class="flex min-h-[calc(100vh-3rem)] flex-col rounded-[2rem] border border-purple-100 bg-[linear-gradient(180deg,rgba(255,255,255,0.98)_0%,rgba(250,245,255,0.94)_55%,rgba(243,232,255,0.9)_100%)] px-5 py-6 text-slate-900 shadow-[0_18px_40px_rgba(88,28,135,0.08)] backdrop-blur">
              <div class="flex items-center gap-3">
                <div class="flex h-11 w-11 items-center justify-center rounded-2xl bg-gradient-to-br from-purple-500 via-fuchsia-500 to-cyan-400 text-base font-semibold">
                  IZ
                </div>
                <div>
                  <p class="text-lg font-semibold tracking-tight text-slate-900">IziHub Finance</p>
                  <p class="text-xs uppercase tracking-[0.24em] text-slate-400">Dashboard</p>
                </div>
              </div>

              <nav class="mt-8 space-y-1.5 text-sm text-slate-600">
                <.side_nav_button active_section={@active_section} section="overview" label="Overview" icon="hero-home" />
                <.side_nav_button active_section={@active_section} section="transactions" label="Transactions" icon="hero-building-library" />
                <.side_nav_button active_section={@active_section} section="review" label={review_section_label(@pending_review_count)} icon="hero-shield-check" />
                <.side_nav_button active_section={@active_section} section="budgets" label="Budgets" icon="hero-chart-bar-square" />
                <.side_nav_button active_section={@active_section} section="debts" label="Debts" icon="hero-banknotes" />
                <.side_nav_button active_section={@active_section} section="insights" label="Insights" icon="hero-wrench-screwdriver" />
              </nav>

              <div class="mt-auto flex items-center gap-3 border-t border-purple-100 pt-5">
                <div class="flex h-11 w-11 items-center justify-center rounded-full bg-emerald-500 text-sm font-semibold text-slate-950">
                  <%= initials(@current_scope.user) %>
                </div>
                <div class="min-w-0">
                  <p class="truncate text-sm font-semibold text-slate-900"><%= current_scope_name(@current_scope.user) %></p>
                  <p class="truncate text-xs text-slate-500"><%= if @ownership_scope == "household" and @selected_household, do: @selected_household.name, else: "Personal scope" %></p>
                </div>
              </div>
            </div>
          </aside>

          <div class="min-w-0 space-y-6 lg:max-w-[92rem]">
            <.finance_dashboard_header :if={@active_section == "overview"} {assigns} />
            <.finance_section_header :if={@active_section != "overview"} {assigns} />

            <nav class="flex gap-2 overflow-x-auto pb-1 xl:hidden">
              <.section_button active_section={@active_section} section="overview" label="Overview" />
              <.section_button active_section={@active_section} section="transactions" label="Transactions" />
              <.section_button active_section={@active_section} section="review" label={review_section_label(@pending_review_count)} />
              <.section_button active_section={@active_section} section="budgets" label="Budgets" />
              <.section_button active_section={@active_section} section="debts" label="Debts" />
              <.section_button active_section={@active_section} section="insights" label="Insights" />
            </nav>

            <div>
              <.overview_section :if={@active_section == "overview"} {assigns} />
              <.transactions_section :if={@active_section == "transactions"} {assigns} />
              <.review_section :if={@active_section == "review"} {assigns} />
              <.budgets_section :if={@active_section == "budgets"} {assigns} />
              <.debts_section :if={@active_section == "debts"} {assigns} />
              <.insights_section :if={@active_section == "insights"} {assigns} />
            </div>
          </div>

          <.focus_panel_modal :if={@focus_panel} panel={@focus_panel} {assigns} />
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp finance_section_header(assigns) do
    ~H"""
    <section>
      <div class="rounded-[1.75rem] border border-purple-100/60 bg-white/86 px-5 py-5 shadow-[0_16px_36px_-30px_rgba(76,29,149,0.16)] backdrop-blur sm:px-6">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div class="space-y-2">
            <p class="text-[11px] font-semibold uppercase tracking-[0.24em] text-slate-400"><%= greeting_date() %></p>
            <h1 class="text-[1.55rem] font-semibold tracking-tight text-slate-950">
              <%= active_section_title(@active_section, @pending_review_count) %>
            </h1>
            <p :if={active_section_subtitle(@active_section)} class="max-w-2xl text-sm leading-6 text-slate-500">
              <%= active_section_subtitle(@active_section) %>
            </p>
          </div>

          <div class="flex flex-wrap items-center justify-end gap-2.5">
            <div class="inline-flex items-center gap-2 rounded-full border border-purple-100/80 bg-purple-50/55 px-1 py-1 shadow-[0_10px_20px_-18px_rgba(88,28,135,0.28)]">
              <button
                type="button"
                phx-click="set_ownership_scope"
                phx-value-scope="personal"
                aria-label="Personal finance scope"
                title="Personal finance scope"
                class={[
                  "inline-flex h-9 items-center gap-2 rounded-full px-3.5 text-sm font-semibold transition",
                  @ownership_scope == "personal" && "bg-white text-purple-700 shadow-sm",
                  @ownership_scope != "personal" && "text-slate-500 hover:bg-white/80 hover:text-slate-900"
                ]}
              >
                <.icon name="hero-user" class="h-4 w-4" />
                Personal
              </button>
              <button
                type="button"
                phx-click={household_scope_available?(@households) && "set_ownership_scope"}
                phx-value-scope="household"
                disabled={!household_scope_available?(@households)}
                aria-label={household_scope_aria_label(@households)}
                title={household_scope_title(@households)}
                class={[
                  "inline-flex h-9 items-center gap-2 rounded-full px-3.5 text-sm font-semibold transition",
                  @ownership_scope == "household" && "bg-white text-purple-700 shadow-sm",
                  @ownership_scope != "household" && household_scope_available?(@households) && "text-slate-500 hover:bg-white/80 hover:text-slate-900",
                  !household_scope_available?(@households) && "text-slate-400"
                ]}
              >
                <.icon name="hero-home" class="h-4 w-4" />
                Household
              </button>
            </div>

            <.household_picker :if={@households != []} households={@households} selected_household_id={@selected_household_id} />
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp finance_dashboard_header(assigns) do
    ~H"""
    <section>
      <div class="rounded-[2.1rem] border border-purple-100/60 bg-[linear-gradient(180deg,rgba(255,255,255,0.94)_0%,rgba(253,250,255,0.88)_100%)] px-6 py-6 shadow-[0_18px_42px_-30px_rgba(76,29,149,0.16)] backdrop-blur sm:px-8">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div class="space-y-4">
            <p class="text-[12px] font-semibold uppercase tracking-[0.24em] text-slate-400"><%= greeting_date() %></p>

            <div class="flex flex-wrap items-center gap-2.5">
              <div class="inline-flex items-center gap-1 rounded-full border border-purple-100/80 bg-purple-50/55 px-1 py-1 shadow-[0_10px_20px_-18px_rgba(88,28,135,0.28)]">
                <button
                  type="button"
                  phx-click="set_ownership_scope"
                  phx-value-scope="personal"
                  aria-label="Personal finance scope"
                  title="Personal finance scope"
                  class={[
                    "inline-flex h-9 items-center gap-2 rounded-full px-3.5 text-sm font-semibold transition",
                    @ownership_scope == "personal" && "bg-white text-purple-700 shadow-sm",
                    @ownership_scope != "personal" && "text-slate-500 hover:bg-white/80 hover:text-slate-900"
                  ]}
                >
                  <.icon name="hero-user" class="h-4 w-4" />
                  Personal
                </button>
                <button
                  type="button"
                  phx-click={household_scope_available?(@households) && "set_ownership_scope"}
                  phx-value-scope="household"
                  disabled={!household_scope_available?(@households)}
                  aria-label={household_scope_aria_label(@households)}
                  title={household_scope_title(@households)}
                  class={[
                    "inline-flex h-9 items-center gap-2 rounded-full px-3.5 text-sm font-semibold transition",
                    @ownership_scope == "household" && "bg-white text-purple-700 shadow-sm",
                    @ownership_scope != "household" && household_scope_available?(@households) && "text-slate-500 hover:bg-white/80 hover:text-slate-900",
                    !household_scope_available?(@households) && "text-slate-400"
                  ]}
                >
                  <.icon name="hero-home" class="h-4 w-4" />
                  Household
                </button>
              </div>

              <.household_picker :if={@households != []} households={@households} selected_household_id={@selected_household_id} />
            </div>
          </div>

          <div class="inline-flex flex-wrap items-center gap-1.5 rounded-full border border-white/80 bg-white/78 px-2 py-2 shadow-[0_10px_26px_-22px_rgba(88,28,135,0.28)]">
            <.time_scope_button current={@time_scope} scope="day" bubble />
            <.time_scope_button current={@time_scope} scope="week" bubble />
            <.time_scope_button current={@time_scope} scope="month" bubble />
            <.time_scope_button current={@time_scope} scope="year" bubble />
          </div>
        </div>

        <div class="mt-4 flex flex-wrap items-center justify-between gap-3">
          <div class="flex flex-wrap items-center gap-2.5">
            <button type="button" phx-click="open_focus_panel" phx-value-panel="transaction" aria-label="Add transaction" title="Add transaction" class="inline-flex h-10 items-center rounded-xl border border-purple-100/80 bg-white/82 px-4 text-sm font-semibold text-slate-800 shadow-[0_12px_24px_-20px_rgba(88,28,135,0.22)] transition hover:border-purple-200 hover:bg-purple-50">
              + Add transaction
            </button>

            <button
              type="button"
              phx-click="open_focus_panel"
              phx-value-panel="household"
              aria-label="Add household"
              title="Add household"
              class="inline-flex h-10 items-center rounded-xl border border-purple-100/80 bg-white/82 px-3.5 text-sm font-semibold text-slate-700 shadow-[0_12px_24px_-20px_rgba(88,28,135,0.22)] transition hover:border-purple-200 hover:bg-purple-50"
            >
              + Household
            </button>

            <button
              type="button"
              phx-click="open_focus_panel"
              phx-value-panel="accounts"
              aria-label="Add account"
              title="Add account"
              class="inline-flex h-10 items-center rounded-xl border border-purple-100/80 bg-white/82 px-3.5 text-sm font-semibold text-slate-700 shadow-[0_12px_24px_-20px_rgba(88,28,135,0.22)] transition hover:border-purple-200 hover:bg-purple-50"
            >
              + Account
            </button>

            <button
              type="button"
              phx-click="open_focus_panel"
              phx-value-panel="budget"
              aria-label="Create budget"
              title="Create budget"
              class="inline-flex h-10 items-center rounded-xl border border-purple-100/80 bg-white/82 px-3.5 text-sm font-semibold text-slate-700 shadow-[0_12px_24px_-20px_rgba(88,28,135,0.22)] transition hover:border-purple-200 hover:bg-purple-50"
            >
              + Budget
            </button>

            <button
              type="button"
              phx-click="open_focus_panel"
              phx-value-panel="debt"
              aria-label="Add debt"
              title="Add debt"
              class="inline-flex h-10 items-center rounded-xl border border-purple-100/80 bg-white/82 px-3.5 text-sm font-semibold text-slate-700 shadow-[0_12px_24px_-20px_rgba(88,28,135,0.22)] transition hover:border-purple-200 hover:bg-purple-50"
            >
              + Debt
            </button>
          </div>
        </div>

        <div class="mt-6 grid gap-5 xl:grid-cols-[minmax(0,1.1fr)_minmax(18rem,0.86fr)]">
          <div class="grid gap-3.5">
            <div class="grid gap-3.5 sm:grid-cols-2">
              <.metric_card
                label="Available cash"
                value={money(@period_summary.balance)}
                note={@date_window_label}
                tone="cash"
                featured
              />
              <.metric_card
                label="Budget remaining"
                value={money(@budget_remaining)}
                note={budget_metric_note(@budget_statuses)}
                tone="budget"
              />
            </div>

            <div class="grid gap-3 sm:grid-cols-2">
              <.metric_card
                label="Income"
                value={money(@period_summary.income)}
                tone="income"
                compact
              />
              <.metric_card
                label="Expenses"
                value={money(@period_summary.expenses)}
                note={expense_metric_note(@transactions)}
                tone="expense"
                compact
              />
            </div>
          </div>

          <div class="grid gap-3.5 lg:grid-cols-2 xl:grid-cols-1">
            <div class="rounded-[1.28rem] border border-white/72 bg-[linear-gradient(180deg,rgba(255,255,255,0.7)_0%,rgba(250,245,255,0.56)_100%)] p-4 shadow-[0_14px_28px_-24px_rgba(88,28,135,0.16)] backdrop-blur-sm">
              <div class="flex items-center justify-between gap-3">
                <h3 class="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">Accounts</h3>
                <button type="button" phx-click="open_focus_panel" phx-value-panel="accounts" class="text-[11px] font-semibold uppercase tracking-[0.16em] text-slate-400 transition hover:text-slate-700">
                  Manage
                </button>
              </div>

              <div class="mt-3.5 space-y-2.5">
                <div :for={summary <- Enum.take(@account_summaries, 2)} class="flex items-center justify-between gap-3 rounded-[1rem] border border-white/80 bg-white/64 px-3 py-2.5">
                  <p class="min-w-0 truncate text-[13px] font-medium text-slate-900"><%= summary.account.name %></p>
                  <p class="font-mono text-[12px] font-semibold text-slate-900"><%= money(summary.account.current_balance) %></p>
                </div>

                <div :if={@account_summaries == []} class="rounded-[1rem] border border-dashed border-purple-100/70 bg-white/50 px-3 py-3 text-xs text-slate-400">
                  No accounts yet.
                </div>
              </div>
            </div>

            <div class="rounded-[1.28rem] border border-white/72 bg-[linear-gradient(180deg,rgba(255,255,255,0.7)_0%,rgba(250,245,255,0.56)_100%)] p-4 shadow-[0_14px_28px_-24px_rgba(88,28,135,0.16)] backdrop-blur-sm">
              <div class="flex items-center justify-between gap-3">
                <h3 class="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">Budgets</h3>
                <button type="button" phx-click="show_section" phx-value-section="budgets" class="text-[11px] font-semibold uppercase tracking-[0.16em] text-slate-400 transition hover:text-slate-700">
                  Open
                </button>
              </div>

              <div class="mt-3.5 space-y-3">
                <.budget_progress_row :for={status <- Enum.take(@budget_statuses, 2)} status={status} />
                <div :if={@budget_statuses == []} class="rounded-[1rem] border border-dashed border-purple-100/70 bg-white/50 px-3 py-3 text-xs text-slate-400">
                  No budgets yet.
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :current, :string, required: true
  attr :scope, :string, required: true
  attr :bubble, :boolean, default: false

  defp time_scope_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="set_time_scope"
      phx-value-scope={@scope}
      class={[
        @bubble && "rounded-full px-3 py-1.5 text-xs font-semibold transition",
        !@bubble && "rounded-full px-3 py-1.5 text-xs font-semibold transition",
        @current == @scope && @bubble && "bg-purple-600 text-white shadow-[0_10px_20px_-16px_rgba(109,40,217,0.55)]",
        @current != @scope && @bubble && "text-slate-500 hover:bg-purple-50/80 hover:text-slate-900",
        @current == @scope && !@bubble && "bg-white text-purple-600 shadow-sm",
        @current != @scope && !@bubble && "text-slate-500 hover:bg-white/80 hover:text-slate-900"
      ]}
    >
      <%= time_scope_title(@scope) %>
    </button>
    """
  end

  attr :households, :list, required: true
  attr :selected_household_id, :string, default: nil

  defp household_picker(assigns) do
    ~H"""
    <form phx-change="select_household">
      <label class="sr-only" for="household_id">Household</label>
      <select
        id="household_id"
        name="household_id"
        class="rounded-full border border-purple-100/80 bg-white/80 px-3.5 py-2 text-sm font-semibold text-slate-700 shadow-[0_10px_20px_-18px_rgba(88,28,135,0.24)]"
      >
        <option :for={household <- @households} value={household.id} selected={household.id == @selected_household_id}>
          <%= household.name %>
        </option>
      </select>
    </form>
    """
  end

  defp household_panel(assigns) do
    ~H"""
    <section class="grid gap-4 lg:grid-cols-[0.92fr_1.08fr]">
      <div class="rounded-xl border border-purple-100 bg-purple-50/55 p-5">
        <div>
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Households</p>
            <h3 class="mt-2 text-xl font-semibold tracking-tight text-slate-950">Create or switch scope</h3>
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

      <div class="rounded-xl border border-purple-100 bg-white p-5 shadow-sm">
        <div class="flex items-start justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Active scope</p>
            <h3 class="mt-2 text-xl font-semibold tracking-tight text-slate-950">
              <%= selected_household_name(@selected_household) %>
            </h3>
          </div>
          <span class="rounded-full border border-purple-100 bg-purple-50 px-3 py-1 text-xs font-semibold text-purple-700">
            <%= household_role_label(@current_scope.user, @selected_household) %>
          </span>
        </div>

        <div class="mt-5 space-y-3">
          <div
            :for={member <- household_member_summaries(@selected_household)}
            class="flex items-center justify-between gap-3 rounded-xl border border-purple-100 bg-purple-50/35 p-4"
          >
            <div>
              <p class="font-semibold text-slate-900"><%= member.name %></p>
              <p class="mt-1 text-xs text-slate-500"><%= member.label %></p>
            </div>
            <span class="rounded-full border border-purple-100 bg-white px-3 py-1 text-xs font-semibold text-slate-600">
              <%= member.role %>
            </span>
          </div>
          <div :if={@selected_household == nil} class="rounded-xl border border-dashed border-purple-100 p-4 text-sm text-slate-500">
            Create a household to start shared tracking.
          </div>
        </div>

        <.form
          :if={household_owner?(@current_scope.user, @selected_household)}
          for={@member_form}
          phx-submit="add_household_member"
          class="mt-5 rounded-xl border border-purple-100 bg-purple-50/45 p-4"
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
              <h3 class="mt-2 text-lg font-semibold text-slate-950">Event budgets</h3>
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
              Use a custom budget period for trips, repairs, or other one-off spending windows.
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
          <p class="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">Tracked balances</p>
          <p class="mt-2 text-2xl font-semibold tracking-tight text-slate-950">
            <%= money(@account_total_balance) %>
          </p>
          <p class="mt-2 text-sm leading-6 text-slate-600"><%= length(@accounts) %> tracked in this scope.</p>
        </div>
      </div>

      <div class="mt-5 grid gap-3 lg:grid-cols-[0.9fr_1.1fr]">
        <div class="space-y-3">
          <div :for={summary <- @account_summaries} class="flex items-center justify-between gap-4 rounded-xl border border-purple-100 bg-white p-4">
            <div>
              <p class="font-semibold text-slate-900"><%= summary.account.name %></p>
              <p class="mt-1 text-xs text-slate-500">
                <%= account_summary_subtitle(summary.account) %> · <%= summary.transaction_count %> linked transactions in view
              </p>
            </div>
            <div class="text-right">
              <p class="text-sm font-semibold text-slate-900"><%= money(summary.account.current_balance) %></p>
              <p class="mt-1 text-xs text-slate-500"><%= signed_decimal(summary.net) %> net in range</p>
            </div>
          </div>

          <div :if={@account_summaries == []} class="rounded-xl border border-dashed border-purple-100 bg-purple-50/50 p-4 text-sm text-slate-500">
            Add accounts to track balances and tie transactions to a real ledger source.
          </div>
        </div>

        <div class="space-y-3">
          <div :for={warning <- @health.warnings} class="rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">
            <%= warning %>
          </div>
          <div :if={@health.warnings == []} class="rounded-xl border border-emerald-200 bg-emerald-50/80 p-4 text-sm text-emerald-900">
            No warnings in the current view.
          </div>
          <div class="rounded-xl border border-purple-100 bg-white p-4 text-sm leading-6 text-slate-600">
            <p class="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Scope</p>
            <p class="mt-3">Personal data stays isolated per user. Household mode only shows shared household data.</p>
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
          <.household_panel :if={@panel == "household"} {assigns} />
          <.transaction_panel :if={@panel == "transaction"} {assigns} />
          <.budget_panel :if={@panel == "budget"} {assigns} />
          <.debt_panel :if={@panel == "debt"} {assigns} />
          <.budget_overview_panel :if={@panel == "budget_overview"} {assigns} />
          <.activity_panel :if={@panel == "activity"} {assigns} />
          <.signals_panel :if={@panel == "signals"} {assigns} />
          <.obligations_panel :if={@panel == "obligations"} {assigns} />
          <.accounts_panel :if={@panel == "accounts"} {assigns} />
        </div>
      </div>
    </div>
    """
  end

  defp accounts_panel(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
      <div class="rounded-2xl border border-purple-100 bg-white/85 p-5 shadow-sm">
        <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Account setup</p>
        <h2 class="mt-2 text-2xl font-semibold tracking-tight text-slate-950">Track balances by scope</h2>

        <.form for={@account_form} phx-submit="create_account" class="mt-5 space-y-4">
          <div class="grid gap-3 sm:grid-cols-2">
            <.finance_input form={@account_form} field={:name} label="Account name" placeholder="Main checking" />
            <.finance_input form={@account_form} field={:institution} label="Institution" placeholder="Popular Bank" />
            <.finance_select form={@account_form} field={:kind} label="Kind" options={account_kind_options()} />
            <.finance_input form={@account_form} field={:currency} label="Currency" placeholder="DOP" />
            <.finance_input form={@account_form} field={:current_balance} label="Current balance" type="number" step="0.01" placeholder="2400.00" />
            <.finance_input form={@account_form} field={:available_balance} label="Available balance" type="number" step="0.01" placeholder="2200.00" />
          </div>

          <.finance_input form={@account_form} field={:notes} label="Notes" placeholder="Optional note" />

          <div class="flex justify-end">
            <button type="submit" class="btn btn-primary btn-sm">Save account</button>
          </div>
        </.form>
      </div>

      <div class="rounded-2xl border border-purple-100 bg-white p-5 shadow-sm">
        <div class="flex items-start justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Tracked accounts</p>
            <h2 class="mt-2 text-2xl font-semibold tracking-tight text-slate-950">Scope balances and activity</h2>
          </div>
          <span class="rounded-full border border-purple-100 bg-purple-50 px-3 py-1 text-xs font-semibold text-purple-700">
            <%= money(@account_total_balance) %>
          </span>
        </div>

        <div class="mt-5 space-y-3">
          <div :for={summary <- @account_summaries} class="rounded-xl border border-purple-100 bg-purple-50/35 p-4">
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="font-semibold text-slate-900"><%= summary.account.name %></p>
                <p class="mt-1 text-xs text-slate-500"><%= account_summary_subtitle(summary.account) %></p>
              </div>
              <div class="text-right">
                <p class="font-semibold text-slate-900"><%= money(summary.account.current_balance) %></p>
                <p class="mt-1 text-xs text-slate-500"><%= signed_decimal(summary.net) %> this range</p>
              </div>
            </div>

            <div class="mt-3 grid gap-2 text-sm text-slate-600 sm:grid-cols-3">
              <.status_row label="Income" value={money(summary.income)} />
              <.status_row label="Expenses" value={money(summary.expenses)} />
              <.status_row label="Linked tx" value={Integer.to_string(summary.transaction_count)} />
            </div>
          </div>

          <div :if={@account_summaries == []} class="rounded-xl border border-dashed border-purple-100 p-4 text-sm text-slate-500">
            No accounts yet for this scope.
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp transaction_panel(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[0.82fr_1.18fr]">
      <div class="rounded-2xl border border-purple-100 bg-white/85 p-5 shadow-sm">
        <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Manual capture</p>
        <h2 class="mt-2 text-2xl font-semibold tracking-tight text-slate-950"><%= transaction_form_title(@editing_transaction_id) %></h2>

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

      <div class="rounded-2xl border border-purple-100 bg-white p-5 shadow-sm">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Ledger</p>
            <h2 class="mt-2 text-2xl font-semibold tracking-tight text-slate-950">Recent transactions</h2>
          </div>
          <span class="text-xs font-semibold text-slate-500"><%= length(@transactions) %> shown</span>
        </div>

        <div class="mt-5 space-y-3">
          <.transaction_row :for={transaction <- Enum.take(@transactions, 6)} transaction={transaction} compact />
          <div :if={@transactions == []} class="rounded-xl border border-dashed border-purple-100 p-4 text-sm text-slate-500">
            Add income and expenses to start tracking cash flow.
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp budget_panel(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[0.82fr_1.18fr]">
      <div class="space-y-5">
        <div class="rounded-2xl border border-purple-100 bg-white/85 p-5 shadow-sm">
          <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Spending plan</p>
          <h2 class="mt-2 text-2xl font-semibold tracking-tight text-slate-950">Create budget</h2>

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

        <div class="rounded-2xl border border-purple-100 bg-white/85 p-5 shadow-sm">
          <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Categories</p>
          <h2 class="mt-2 text-2xl font-semibold tracking-tight text-slate-950">Add category</h2>

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

      <div class="rounded-2xl border border-purple-100 bg-white p-5 shadow-sm">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Active budgets</p>
            <h2 class="mt-2 text-2xl font-semibold tracking-tight text-slate-950">Budget status</h2>
          </div>
          <span class="text-xs font-semibold text-slate-500"><%= money(@budget_remaining) %> remaining</span>
        </div>

        <div class="mt-5 space-y-3">
          <.budget_status_card :for={status <- @budget_statuses} status={status} />
          <div :if={@budget_statuses == []} class="rounded-xl border border-dashed border-purple-100 p-4 text-sm text-slate-500">
            No active budgets yet.
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp debt_panel(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
      <div class="rounded-2xl border border-purple-100 bg-white p-5 shadow-sm">
        <div>
          <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Debt setup</p>
          <h2 class="mt-2 text-2xl font-semibold tracking-tight text-slate-950">Add debt</h2>
        </div>

        <.form for={@debt_form} phx-submit="create_debt" class="mt-5 rounded-xl border border-purple-100 bg-purple-50/45 p-4">
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

          <div class="mt-4 flex justify-end">
            <button type="submit" class="btn btn-primary btn-sm">Save debt</button>
          </div>
        </.form>

        <div class="mt-5 space-y-3">
          <div :if={@debts == []} class="rounded-xl border border-dashed border-purple-100 p-4 text-sm text-slate-500">
            Add debts to compare payoff strategies.
          </div>

          <.debt_card :for={debt <- @debts} debt={debt} payment_form={@payment_form} payment_form_debt_id={@payment_form_debt_id} />
        </div>
      </div>

      <div class="rounded-2xl border border-purple-100 bg-white p-5 shadow-sm">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Payoff comparison</p>
            <h2 class="mt-2 text-2xl font-semibold tracking-tight text-slate-950">Snowball vs avalanche</h2>
          </div>
          <button type="button" phx-click="generate_plans" class="btn btn-primary btn-xs">Refresh</button>
        </div>

        <div class="mt-5 grid gap-4 lg:grid-cols-2">
          <.plan_card :for={plan <- @comparison} plan={plan} />
          <div :if={@comparison == []} class="rounded-lg border border-dashed border-slate-200 p-4 text-sm text-slate-500 lg:col-span-2">
            Generate plans to compare payoff order, payoff month, and estimated interest.
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp overview_section(assigns) do
    ~H"""
    <section class="relative overflow-hidden rounded-[2.45rem] border border-purple-100/80 bg-[linear-gradient(180deg,rgba(255,255,255,0.98)_0%,rgba(251,247,255,0.95)_38%,rgba(244,236,255,0.9)_100%)] p-5 shadow-[0_28px_60px_-38px_rgba(88,28,135,0.22)] sm:p-6 xl:p-7">
      <div class="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(255,255,255,0.68),transparent_34%),radial-gradient(circle_at_85%_18%,rgba(255,255,255,0.32),transparent_18%),radial-gradient(circle_at_bottom_right,rgba(196,181,253,0.22),transparent_30%)]" />

      <div class="relative grid gap-5 xl:grid-cols-[minmax(0,1.2fr)_minmax(18rem,0.8fr)]">
        <.overview_glass_pane>
          <div class="flex flex-wrap items-start justify-between gap-4">
            <div>
              <p class="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-400">Flow</p>
              <h2 class="mt-2 text-[1.65rem] font-semibold tracking-tight text-slate-950">Income vs. spending</h2>
            </div>

            <div class="flex flex-wrap items-center justify-end gap-2">
              <span class="inline-flex items-center gap-2 rounded-full border border-white/80 bg-white/62 px-3 py-1.5 text-xs font-medium text-slate-600 backdrop-blur-sm">
                <span class="inline-flex h-5 min-w-5 items-center justify-center rounded-full bg-purple-100 px-1 text-[11px] font-semibold text-purple-700">
                  <%= length(@accounts) %>
                </span>
                Accounts
              </span>
              <span class="inline-flex items-center gap-2 rounded-full border border-white/80 bg-white/62 px-3 py-1.5 text-xs font-medium text-slate-600 backdrop-blur-sm">
                <.icon name="hero-wallet" class="h-3.5 w-3.5 text-emerald-600" />
                <%= money(@health.current_month.free_cash_flow) %>
              </span>
              <div class="flex items-center gap-4 text-[11px] text-slate-500">
                <span class="flex items-center gap-1.5"><span class="inline-block h-2.5 w-2.5 rounded-full bg-emerald-600"></span>Income</span>
                <span class="flex items-center gap-1.5"><span class="inline-block h-2.5 w-2.5 rounded-full bg-rose-500"></span>Spending</span>
              </div>
            </div>
          </div>

          <div class="mt-5 grid gap-4 lg:grid-cols-[minmax(0,1.12fr)_0.88fr]">
            <div class="rounded-[1.55rem] border border-white/75 bg-white/56 p-5 shadow-[0_18px_32px_-26px_rgba(88,28,135,0.18)] backdrop-blur-sm">
              <div class="flex h-[15rem] items-end justify-between gap-5">
                <.comparison_bar label="Current" left={@health.current_month.income} right={@health.current_month.expenses} />
                <.comparison_bar label="Next" left={@health.next_month.income} right={@health.next_month.expenses} />
                <.comparison_bar label="Net flow" left={@period_summary.income} right={@period_summary.expenses} active />
              </div>
            </div>

            <div class="grid gap-4">
              <div class="rounded-[1.55rem] border border-white/75 bg-[linear-gradient(160deg,rgba(255,255,255,0.7)_0%,rgba(240,249,255,0.58)_100%)] p-5 shadow-[0_18px_32px_-26px_rgba(88,28,135,0.16)] backdrop-blur-sm">
                <p class="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">Scope balance</p>
                <p class="mt-4 text-[2.3rem] font-semibold tracking-tight text-slate-950"><%= money(@account_total_balance) %></p>
                <p class={["mt-3 text-sm font-medium", Decimal.compare(@period_summary.balance, Decimal.new("0")) == :lt && "text-rose-600", Decimal.compare(@period_summary.balance, Decimal.new("0")) != :lt && "text-emerald-600"]}>
                  <%= signed_decimal(@period_summary.balance) %> in <%= String.downcase(time_scope_title(@time_scope)) %> view
                </p>
              </div>

              <div class="grid gap-3 sm:grid-cols-2">
                <button
                  type="button"
                  phx-click="open_focus_panel"
                  phx-value-panel="accounts"
                  class="flex min-h-[6.4rem] flex-col justify-between rounded-[1.45rem] border border-white/78 bg-white/54 p-4 text-left shadow-[0_14px_28px_-26px_rgba(88,28,135,0.16)] backdrop-blur-sm transition hover:bg-white/70"
                >
                  <span class="inline-flex h-8 w-8 items-center justify-center rounded-full bg-purple-100/90 text-purple-700">
                    <.icon name="hero-building-library" class="h-4 w-4" />
                  </span>
                  <div>
                    <p class="font-semibold text-slate-900">Accounts</p>
                    <p class="mt-1 text-xs text-slate-500"><%= money(@account_total_balance) %></p>
                  </div>
                </button>

                <button
                  type="button"
                  phx-click="show_section"
                  phx-value-section="review"
                  class="flex min-h-[6.4rem] flex-col justify-between rounded-[1.45rem] border border-white/78 bg-white/54 p-4 text-left shadow-[0_14px_28px_-26px_rgba(88,28,135,0.16)] backdrop-blur-sm transition hover:bg-white/70"
                >
                  <span class="inline-flex h-8 w-8 items-center justify-center rounded-full bg-amber-100 text-amber-700">
                    <.icon name="hero-shield-check" class="h-4 w-4" />
                  </span>
                  <div>
                    <p class="font-semibold text-slate-900">Review</p>
                    <p class="mt-1 text-xs text-slate-500"><%= pending_review_note(@pending_review_count) %></p>
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
              <h2 class="mt-2 text-xl font-semibold tracking-tight text-slate-950">Recent transactions</h2>
            </div>
            <button type="button" phx-click="show_section" phx-value-section="transactions" class="text-[11px] font-semibold uppercase tracking-[0.16em] text-slate-400 transition hover:text-slate-700">
              View all
            </button>
          </div>

          <div class="mt-5 space-y-2.5">
            <div :for={transaction <- Enum.take(@transactions, 5)} class="rounded-[1.12rem] border border-white/78 bg-white/56 px-4 py-3.5 backdrop-blur-sm">
              <div class="flex items-start justify-between gap-3">
                <div class="min-w-0">
                  <p class="truncate font-medium text-slate-900"><%= transaction.description || review_title(transaction) %></p>
                  <div class="mt-2 flex flex-wrap items-center gap-2 text-[11px] text-slate-500">
                    <span><%= format_date(transaction.transaction_date) %></span>
                    <span :if={transaction.account} class="rounded-full bg-purple-50/90 px-2 py-1"><%= transaction.account.name %></span>
                  </div>
                </div>
                <p class={["pt-0.5 font-mono text-sm font-semibold", transaction_type_class(transaction.type)]}>
                  <%= signed_money(transaction) %>
                </p>
              </div>
            </div>

            <div :if={@transactions == []} class="rounded-[1.1rem] border border-dashed border-purple-100/70 bg-white/50 px-4 py-5 text-sm text-slate-400 backdrop-blur-sm">
              No transactions yet.
            </div>
          </div>
        </.overview_glass_pane>

        <.overview_glass_pane class="xl:col-span-2">
          <div class="grid gap-4 xl:grid-cols-2">
            <div class="rounded-[1.55rem] border border-white/78 bg-white/54 p-5 shadow-[0_16px_28px_-28px_rgba(88,28,135,0.15)] backdrop-blur-sm">
              <div class="flex items-center justify-between gap-3">
                <div>
                  <p class="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-400">Review</p>
                  <h2 class="mt-2 text-lg font-semibold text-slate-950">Pending queue</h2>
                </div>
                <button type="button" phx-click="show_section" phx-value-section="review" class="text-[11px] font-semibold uppercase tracking-[0.16em] text-slate-400 transition hover:text-slate-700">
                  Open review queue
                </button>
              </div>

              <div class="mt-5 space-y-2.5">
                <div :for={transaction <- Enum.take(@pending_transactions, 3)} class="rounded-[1.05rem] border border-white/78 bg-white/58 p-3.5 backdrop-blur-sm">
                  <div class="flex items-start justify-between gap-3">
                    <div class="min-w-0">
                      <p class="truncate font-medium text-slate-900"><%= review_title(transaction) %></p>
                      <p class="mt-1 text-xs text-slate-500"><%= format_date(transaction.transaction_date) %></p>
                    </div>
                    <span class="rounded-full bg-amber-100 px-2 py-1 text-[11px] font-semibold text-amber-800">Review</span>
                  </div>
                </div>

                <div :if={@pending_transactions == []} class="rounded-[1rem] border border-dashed border-purple-100/70 bg-white/50 px-4 py-4 text-sm text-slate-400 backdrop-blur-sm">
                  Queue clear.
                </div>
              </div>
            </div>

            <div class="rounded-[1.55rem] border border-white/78 bg-white/54 p-5 shadow-[0_16px_28px_-28px_rgba(88,28,135,0.15)] backdrop-blur-sm">
              <div class="flex items-center justify-between gap-3">
                <div>
                  <p class="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-400">Obligations</p>
                  <h2 class="mt-2 text-lg font-semibold text-slate-950">Debts</h2>
                </div>
                <button type="button" phx-click="show_section" phx-value-section="debts" class="text-[11px] font-semibold uppercase tracking-[0.16em] text-slate-400 transition hover:text-slate-700">
                  Details
                </button>
              </div>

              <div class="mt-5 space-y-2.5">
                <div :for={debt <- Enum.take(@debts, 3)} class="rounded-[1.05rem] border border-white/78 bg-white/58 px-4 py-3.5 backdrop-blur-sm">
                  <div class="flex items-start justify-between gap-4">
                    <div>
                      <p class="font-medium text-slate-900"><%= debt.name %></p>
                      <p class="mt-1 text-xs text-slate-500"><%= due_day_label(debt.due_day) %></p>
                    </div>
                    <div class="text-right">
                      <p class="font-mono text-sm font-semibold text-slate-900"><%= money(debt.current_balance) %></p>
                      <p class="mt-1 text-xs text-slate-500"><%= money(debt.minimum_payment) %> min</p>
                    </div>
                  </div>
                </div>

                <div :if={@debts == []} class="rounded-[1rem] border border-dashed border-purple-100/70 bg-white/50 px-4 py-4 text-sm text-slate-400 backdrop-blur-sm">
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

  defp transactions_section(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[0.72fr_1.28fr]">
      <div class="rounded-[1.75rem] border border-purple-100/70 bg-white/88 p-5 shadow-[0_18px_36px_-32px_rgba(88,28,135,0.18)] backdrop-blur sm:p-6">
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Capture</p>
        <h2 class="mt-1 text-xl font-semibold text-slate-950">Transactions</h2>
        <div class="mt-5">
          <button type="button" phx-click="open_focus_panel" phx-value-panel="transaction" class="btn btn-primary btn-sm">
            + Add transaction
          </button>
        </div>
      </div>

      <div class="rounded-[1.75rem] border border-purple-100/70 bg-white/88 p-5 shadow-[0_18px_36px_-32px_rgba(88,28,135,0.18)] backdrop-blur sm:p-6">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Ledger</p>
            <h2 class="mt-1 text-xl font-semibold text-slate-950">Recent transactions</h2>
          </div>
          <span class="text-xs font-semibold text-slate-500"><%= length(@transactions) %> shown</span>
        </div>

        <div class="mt-4 space-y-3">
          <.transaction_row :for={transaction <- @transactions} transaction={transaction} />
          <div :if={@transactions == []} class="rounded-xl border border-dashed border-purple-100/70 bg-purple-50/35 p-4 text-sm text-slate-500">
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
      <div class="rounded-[1.75rem] border border-purple-100/70 bg-white/88 p-5 shadow-[0_18px_36px_-32px_rgba(88,28,135,0.18)] backdrop-blur sm:p-6">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Pending review</p>
            <h2 class="mt-1 text-xl font-semibold text-slate-950">Imported transaction suggestions</h2>
          </div>
          <span class="text-xs font-semibold text-slate-500"><%= @pending_review_count %> waiting</span>
        </div>

        <div class="mt-4 space-y-3">
          <.review_row :for={transaction <- @pending_transactions} transaction={transaction} />
          <div :if={@pending_transactions == []} class="rounded-xl border border-dashed border-purple-100/70 bg-purple-50/35 p-4 text-sm text-slate-500">
            No pending items right now.
          </div>
        </div>
      </div>

      <div class="rounded-[1.75rem] border border-purple-100/70 bg-white/88 p-5 shadow-[0_18px_36px_-32px_rgba(88,28,135,0.18)] backdrop-blur sm:p-6">
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Review cadence</p>
        <h2 class="mt-1 text-xl font-semibold text-slate-950">What happens here</h2>
        <div class="mt-5 space-y-3 text-sm leading-6 text-slate-600">
          <p>Imported candidates wait here before they affect balances and budgets.</p>
          <p>Confirm keeps the item in the ledger. Ignore removes the suggestion.</p>
          <p>Edit lets you correct the details before confirming.</p>
        </div>
      </div>
    </section>
    """
  end

  defp budgets_section(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[0.72fr_1.28fr]">
      <div class="rounded-[1.75rem] border border-purple-100/70 bg-white/88 p-5 shadow-[0_18px_36px_-32px_rgba(88,28,135,0.18)] backdrop-blur sm:p-6">
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Planning</p>
        <h2 class="mt-1 text-xl font-semibold text-slate-950">Budgets</h2>
        <div class="mt-5">
          <button type="button" phx-click="open_focus_panel" phx-value-panel="budget" class="btn btn-primary btn-sm">
            + Budget
          </button>
        </div>
      </div>

      <div class="rounded-[1.75rem] border border-purple-100/70 bg-white/88 p-5 shadow-[0_18px_36px_-32px_rgba(88,28,135,0.18)] backdrop-blur sm:p-6">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Active budgets</p>
            <h2 class="mt-1 text-xl font-semibold text-slate-950">Budget status</h2>
          </div>
          <span class="text-xs font-semibold text-slate-500"><%= money(@budget_remaining) %> remaining</span>
        </div>

        <div class="mt-4 space-y-3">
          <.budget_status_card :for={status <- @budget_statuses} status={status} />
          <div :if={@budget_statuses == []} class="rounded-xl border border-dashed border-purple-100/70 bg-purple-50/35 p-4 text-sm text-slate-500">
            No active budgets yet.
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp debts_section(assigns) do
    ~H"""
    <section class="grid gap-5 xl:grid-cols-[0.72fr_1.28fr]">
      <div class="rounded-[1.75rem] border border-purple-100/70 bg-white/88 p-5 shadow-[0_18px_36px_-32px_rgba(88,28,135,0.18)] backdrop-blur sm:p-6">
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Obligations</p>
        <h2 class="mt-1 text-xl font-semibold text-slate-950">Debts</h2>
        <div class="mt-5">
          <button type="button" phx-click="open_focus_panel" phx-value-panel="debt" class="btn btn-primary btn-sm">
            + Debt
          </button>
        </div>

        <div class="mt-5 space-y-3">
          <div :if={@debts == []} class="rounded-xl border border-dashed border-purple-100/70 bg-purple-50/35 p-4 text-sm text-slate-500">
            Add debts to compare payoff strategies.
          </div>

          <.debt_card :for={debt <- @debts} debt={debt} payment_form={@payment_form} payment_form_debt_id={@payment_form_debt_id} />
        </div>
      </div>

      <div class="rounded-[1.75rem] border border-purple-100/70 bg-white/88 p-5 shadow-[0_18px_36px_-32px_rgba(88,28,135,0.18)] backdrop-blur sm:p-6">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Payoff comparison</p>
            <h2 class="mt-1 text-xl font-semibold text-slate-950">Snowball vs avalanche</h2>
          </div>
          <button type="button" phx-click="generate_plans" class="btn btn-primary btn-xs">Refresh</button>
        </div>

        <div class="mt-5 grid gap-4 lg:grid-cols-2">
          <.plan_card :for={plan <- @comparison} plan={plan} />
          <div :if={@comparison == []} class="rounded-xl border border-dashed border-purple-100/70 bg-purple-50/35 p-4 text-sm text-slate-500 lg:col-span-2">
            Generate plans to compare payoff order, payoff month, and estimated interest.
          </div>
        </div>

        <div class="mt-6">
          <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Saved plans</p>
          <div class="mt-3 space-y-2">
            <div :if={@plans == []} class="rounded-xl border border-purple-100/70 bg-purple-50/35 p-4 text-sm text-slate-500">
              No saved payoff plans yet.
            </div>
            <div :for={plan <- @plans} class="flex items-center justify-between gap-4 rounded-xl border border-purple-100/70 bg-white/86 p-4">
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
      <div class="rounded-[1.75rem] border border-purple-100/70 bg-white/88 p-5 shadow-[0_18px_36px_-32px_rgba(88,28,135,0.18)] backdrop-blur sm:p-6">
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Signals</p>
        <h2 class="mt-1 text-xl font-semibold text-slate-950">Financial health</h2>

        <div class="mt-5 space-y-3">
          <.status_row label="Debt-to-income" value={"#{@health.debt_to_income_ratio}%"} />
          <.status_row label="Minimum payment burden" value={"#{@health.minimum_payment_burden}%"} />
          <.status_row label="Monthly debt minimums" value={money(@health.minimum_debt_payment)} />
          <.status_row label="Current free cash flow" value={money(@health.current_month.free_cash_flow)} />
        </div>
      </div>

      <div class="rounded-[1.75rem] border border-purple-100/70 bg-white/88 p-5 shadow-[0_18px_36px_-32px_rgba(88,28,135,0.18)] backdrop-blur sm:p-6">
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Reading guide</p>
        <h2 class="mt-1 text-xl font-semibold text-slate-950">How to read this snapshot</h2>
        <div class="mt-5 space-y-3 text-sm leading-6 text-slate-600">
          <p>Health metrics reflect confirmed transactions in the active scope.</p>
          <p>Warnings call out pressure points worth reviewing before they become problems.</p>
        </div>
      </div>

      <div class="rounded-[1.75rem] border border-purple-100/70 bg-white/88 p-5 shadow-[0_18px_36px_-32px_rgba(88,28,135,0.18)] backdrop-blur sm:p-6 lg:col-span-2">
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Warnings</p>
        <div class="mt-4 space-y-2">
          <div :for={warning <- @health.warnings} class="rounded-lg border border-amber-200 bg-amber-50 p-3 text-sm text-amber-900">
            <%= warning %>
          </div>
          <div :if={@health.warnings == []} class="rounded-lg border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-900">
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

  defp metric_card(assigns) do
    ~H"""
    <div
      class={[
        "rounded-[1.15rem] border transition duration-200 hover:-translate-y-0.5",
        @compact && "p-3",
        !@compact && "p-4",
        @featured && "border-purple-200/80 bg-[linear-gradient(160deg,rgba(109,40,217,0.9)_0%,rgba(124,58,237,0.82)_48%,rgba(196,181,253,0.86)_100%)] text-white shadow-[0_18px_40px_-26px_rgba(109,40,217,0.34)]",
        !@featured && "border-white/78 bg-[linear-gradient(180deg,rgba(255,255,255,0.86)_0%,rgba(251,247,255,0.68)_100%)] shadow-[0_14px_28px_-24px_rgba(88,28,135,0.12)]"
      ]}
    >
      <p class={["text-[10px] font-semibold uppercase tracking-[0.2em]", @featured && "text-white/55", !@featured && "text-slate-400"]}>
        <%= @label %>
      </p>
      <p class={["font-mono font-semibold leading-none tracking-[-0.035em]", @compact && "mt-2 text-[1.12rem]", !@compact && "mt-3 text-[1.42rem]", @featured && "text-white", !@featured && metric_tone_class(@tone)]}>
        <%= @value %>
      </p>
      <p :if={@note} class={["text-[10px] leading-4", @compact && "mt-1.5", !@compact && "mt-2.5", @featured && "text-purple-100/80", !@featured && "text-slate-500"]}>
        <%= @note %>
      </p>
    </div>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true

  defp overview_glass_pane(assigns) do
    ~H"""
    <section
      class={[
        "relative overflow-hidden rounded-[1.85rem] border border-white/76 bg-[linear-gradient(180deg,rgba(255,255,255,0.66)_0%,rgba(250,245,255,0.54)_100%)] p-5 shadow-[0_18px_32px_-28px_rgba(88,28,135,0.16)] backdrop-blur-md sm:p-6",
        @class
      ]}
    >
      <div class="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(255,255,255,0.62),transparent_42%),radial-gradient(circle_at_bottom_right,rgba(255,255,255,0.16),transparent_24%)] opacity-80" />
      <div class="relative"><%= render_slot(@inner_block) %></div>
    </section>
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
        "shrink-0 rounded-2xl px-3.5 py-2 text-sm font-semibold transition xl:flex xl:w-full xl:items-center xl:justify-start xl:px-4 xl:py-3",
        @active_section == @section && "bg-purple-600 text-white shadow-sm xl:bg-purple-50 xl:text-purple-700",
        @active_section != @section && "border border-purple-100 bg-white text-slate-600 hover:bg-purple-50 hover:text-slate-950 xl:border-transparent"
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

  defp side_nav_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="show_section"
      phx-value-section={@section}
      class={[
        "flex w-full items-center gap-3 rounded-xl px-4 py-3 text-left transition",
        @active_section == @section && "border border-purple-100 bg-white text-purple-700 shadow-sm",
        @active_section != @section && "text-slate-600 hover:bg-purple-50 hover:text-slate-900"
      ]}
    >
      <.icon name={@icon} class="h-[17px] w-[17px]" />
      <span><%= @label %></span>
    </button>
    """
  end

  attr :title, :string, required: true
  attr :month, :map, required: true

  defp month_card(assigns) do
    ~H"""
    <div class="rounded-xl border border-purple-100 bg-purple-50/35 p-4">
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

  attr :label, :string, required: true
  attr :left, :any, required: true
  attr :right, :any, required: true
  attr :active, :boolean, default: false

  defp comparison_bar(assigns) do
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
        <div class="w-5 rounded-t-[0.9rem] bg-emerald-600/95" style={"height: #{@left_height}px"} />
        <div class="w-5 rounded-t-[0.9rem] bg-rose-500/95" style={"height: #{@right_height}px"} />
      </div>
      <span class={["text-xs", @active && "font-semibold text-slate-900", !@active && "text-slate-500"]}><%= @label %></span>
    </div>
    """
  end

  attr :transaction, Transaction, required: true

  defp transaction_table_row(assigns) do
    ~H"""
    <div class="grid grid-cols-[minmax(0,1.2fr)_auto_auto] items-center gap-3 px-5 py-4">
      <div class="min-w-0">
        <p class="truncate font-medium text-slate-900"><%= @transaction.description || review_title(@transaction) %></p>
        <p class="mt-1 text-xs text-slate-500">
          <%= category_name(@transaction.category) %> · <%= format_date(@transaction.transaction_date) %>
        </p>
      </div>
      <p class={["text-right font-mono text-sm font-semibold", transaction_type_class(@transaction.type)]}>
        <%= signed_money(@transaction) %>
      </p>
      <p class="truncate text-right font-mono text-sm text-slate-500">
        <%= @transaction.account && @transaction.account.name || "Unassigned" %>
      </p>
    </div>
    """
  end

  attr :status, :map, required: true

  defp budget_progress_row(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between gap-4 text-sm">
        <span class="font-medium text-slate-900"><%= @status.budget.name %></span>
        <span class="font-mono text-[12px] text-slate-500"><%= money(@status.spent) %> / <%= money(@status.budget.amount) %></span>
      </div>
      <div class="mt-2.5 h-1.5 overflow-hidden rounded-full bg-purple-100/90">
        <div class={["h-full rounded-full", budget_progress_class(@status)]} style={"width: #{min(@status.percentage, 100)}%"} />
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
          <%= if @transaction.account, do: " · #{@transaction.account.name}" %>
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
    user = current_actor(socket)
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
    period_window = period_window(time_scope, event_budget_statuses, Date.utc_today())

    {:ok, account_summaries} =
      Finance.list_account_summaries(
        user,
        owner,
        period_window.start_date,
        period_window.end_date
      )

    period_summary =
      Finance.get_financial_summary(owner, period_window.start_date, period_window.end_date)

    {:ok, transactions} =
      Finance.list_transactions(user, owner,
        limit: 20,
        status: ["confirmed", "pending_review"],
        start_date: period_window.start_date,
        end_date: period_window.end_date
      )

    confirmed_transactions = Enum.filter(transactions, &(&1.status == "confirmed"))
    {:ok, debts} = Finance.list_debts(user, owner)
    {:ok, plans} = Finance.list_payoff_plans(user, owner)
    health = Finance.get_financial_health(user, owner, today: Date.utc_today())

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
        expense_categories: Enum.filter(categories, &(&1.type == "expense")),
        date_window_label: period_window.label,
        period_summary: period_summary,
        transactions: transactions,
        pending_transactions: pending_transactions,
        pending_review_count: length(pending_transactions),
        budget_statuses: budget_statuses,
        event_budget_statuses: event_budget_statuses,
        budget_remaining: budget_remaining(budget_statuses),
        debts: debts,
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

  defp assign_account_form(socket) do
    account = %Account{kind: "checking", currency: "DOP", current_balance: Decimal.new("0")}
    assign(socket, account_form: to_form(Finance.change_account(account), as: :account))
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

  defp prepare_focus_panel(socket, "accounts") do
    socket
    |> assign_account_form()
    |> open_action_surface("accounts")
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

  defp account_kind_options do
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

  defp account_options(accounts) do
    [{"Not set", ""}] ++ Enum.map(accounts, &{&1.name, &1.id})
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

  defp signed_decimal(%Decimal{} = amount) do
    case Decimal.compare(amount, Decimal.new("0")) do
      :lt -> "-#{money(Decimal.abs(amount))}"
      _ -> "+#{money(amount)}"
    end
  end

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

  defp account_summary_subtitle(account) do
    [account.institution, format_kind(account.kind), account.currency]
    |> Enum.reject(&is_nil_or_empty/1)
    |> Enum.join(" · ")
  end

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

  defp active_section_title("overview", _pending_review_count), do: "Overview"
  defp active_section_title("transactions", _pending_review_count), do: "Transactions"
  defp active_section_title("review", 0), do: "Review queue"
  defp active_section_title("review", count), do: "Review queue (#{count})"
  defp active_section_title("budgets", _pending_review_count), do: "Budgets"
  defp active_section_title("debts", _pending_review_count), do: "Debts"
  defp active_section_title("insights", _pending_review_count), do: "Insights"

  defp active_section_subtitle("overview"), do: nil
  defp active_section_subtitle("transactions"), do: nil
  defp active_section_subtitle("review"), do: nil
  defp active_section_subtitle("budgets"), do: nil
  defp active_section_subtitle("debts"), do: nil
  defp active_section_subtitle("insights"), do: nil

  defp budget_metric_note([]), do: "No active budgets"
  defp budget_metric_note(budgets), do: "#{length(budgets)} active"

  defp expense_metric_note([]), do: "No spend yet"
  defp expense_metric_note(transactions), do: "#{length(transactions)} in view"

  defp pending_review_note(0), do: "Queue clear"
  defp pending_review_note(1), do: "1 item waiting"
  defp pending_review_note(count), do: "#{count} items waiting"

  defp budget_state_label(%{is_over: true}), do: "Over"
  defp budget_state_label(%{is_near_limit: true}), do: "Near limit"
  defp budget_state_label(_status), do: "On track"

  defp budget_state_class(%{is_over: true}), do: "bg-rose-100 text-rose-700"
  defp budget_state_class(%{is_near_limit: true}), do: "bg-amber-100 text-amber-800"
  defp budget_state_class(_status), do: "bg-emerald-100 text-emerald-700"

  defp budget_progress_class(%{is_over: true}), do: "bg-rose-500"
  defp budget_progress_class(%{is_near_limit: true}), do: "bg-amber-500"
  defp budget_progress_class(_status), do: "bg-emerald-500"

  defp household_scope_available?(households), do: households != []

  defp household_scope_aria_label([]), do: "Household finance scope coming soon"
  defp household_scope_aria_label(_households), do: "Household finance scope"

  defp household_scope_title([]), do: "Household coming soon"
  defp household_scope_title(_households), do: "Household"

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

  defp time_scope_title("day"), do: "Day"
  defp time_scope_title("week"), do: "Week"
  defp time_scope_title("month"), do: "Month"
  defp time_scope_title("year"), do: "Year"
  defp time_scope_title("event"), do: "Event"

  defp greeting_date do
    Date.utc_today()
    |> Calendar.strftime("%A, %B %-d")
  end

  defp current_scope_name(user) do
    user.full_name || user.username || user.email || "User"
  end

  defp initials(user) do
    user
    |> current_scope_name()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
    |> String.upcase()
  end

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

  defp due_day_label(nil), do: "Due day not set"
  defp due_day_label(due_day), do: "Due on day #{due_day}"

  defp selected_household_name(nil), do: "Household"
  defp selected_household_name(household), do: household.name

  defp household_owner?(_user, nil), do: false
  defp household_owner?(user, household), do: Accounts.user_household_owner?(user, household.id)

  defp household_role_label(_user, nil), do: "Personal"

  defp household_role_label(user, household) do
    if household_owner?(user, household), do: "Owner", else: "Member"
  end

  defp household_member_summaries(nil), do: []

  defp household_member_summaries(household) do
    Enum.map(household.memberships, fn membership ->
      %{
        name: membership.user.full_name || membership.user.username || membership.user.email,
        label: membership.user.username || membership.user.email,
        role: String.capitalize(membership.role)
      }
    end)
  end

  defp format_period_window(start_date, end_date) do
    "#{format_date(start_date)} to #{format_date(end_date)}"
  end

  defp decimal_to_float(%Decimal{} = value), do: Decimal.to_float(value)
  defp decimal_to_float(value) when is_integer(value), do: value * 1.0
  defp decimal_to_float(value) when is_float(value), do: value
  defp decimal_to_float(_value), do: 0.0

  defp scaled_bar_height(value, max_amount) do
    value
    |> decimal_to_float()
    |> Kernel./(max(max_amount, 1.0))
    |> Kernel.*(120)
    |> round()
    |> max(12)
  end

  defp focus_panel_title("budget_overview"), do: "Budget overview"
  defp focus_panel_title("activity"), do: "Recent activity"
  defp focus_panel_title("signals"), do: "Signals and visibility"
  defp focus_panel_title("obligations"), do: "Obligations and payoff plans"
  defp focus_panel_title("accounts"), do: "Accounts and balances"
  defp focus_panel_title("transaction"), do: "Add transaction"
  defp focus_panel_title("budget"), do: "Budget setup"
  defp focus_panel_title("debt"), do: "Debt setup"
  defp focus_panel_title("household"), do: "Household setup"

  defp is_nil_or_empty(nil), do: true
  defp is_nil_or_empty(""), do: true
  defp is_nil_or_empty(_value), do: false

  defp translate_error({message, opts}) do
    Enum.reduce(opts, message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end

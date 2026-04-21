defmodule CoreWeb.FinanceLive do
  use CoreWeb, :live_view

  alias Core.Finance

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:current_scope, fn -> nil end)
     |> assign(
       page_title: "IziFinance",
       debt_form_open: false,
       comparison: []
     )
     |> assign_debt_form()
     |> assign_finance_data()}
  end

  def handle_event("open_debt_form", _params, socket) do
    {:noreply, assign(socket, debt_form_open: true)}
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
         |> assign_finance_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(debt_form_open: true)
         |> assign(debt_form: to_form(changeset, as: :debt))}
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
    {:noreply, assign(socket, comparison: comparison)}
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
        <main class="mx-auto max-w-7xl px-6 pb-16 pt-12">
          <section class="mb-8 flex flex-wrap items-end justify-between gap-4">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.24em] text-purple-500">Debt consolidation studio</p>
              <h1 class="mt-3 text-4xl font-semibold tracking-tight text-slate-900 sm:text-5xl">
                IziFinance
              </h1>
              <p class="mt-3 max-w-2xl text-sm leading-6 text-slate-600">
                Consolidate manual debt balances, compare snowball and avalanche payoff paths, and monitor current-month financial health.
              </p>
            </div>

            <div class="flex flex-wrap gap-2">
              <button type="button" phx-click="generate_plans" class="btn btn-primary btn-sm">
                Compare plans
              </button>
              <button type="button" phx-click="open_debt_form" class="btn btn-secondary btn-sm">
                Add debt
              </button>
            </div>
          </section>

          <section class="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
            <.metric_card label="Current income" value={money(@health.current_month.income)} accent="text-emerald-600" />
            <.metric_card label="Current expenses" value={money(@health.current_month.expenses)} accent="text-rose-600" />
            <.metric_card label="Free cash flow" value={money(@health.current_month.free_cash_flow)} accent="text-purple-600" />
            <.metric_card label="Total debt" value={money(@health.total_debt)} accent="text-slate-900" />
          </section>

          <section class="mt-5 grid gap-5 xl:grid-cols-[1.2fr_0.8fr]">
            <div class="rounded-[2rem] border border-purple-100 bg-white/85 p-6 shadow-[0_30px_80px_-45px_rgba(109,40,217,0.45)]">
              <div class="flex flex-wrap items-start justify-between gap-4">
                <div>
                  <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Cash flow projection</p>
                  <h2 class="mt-2 text-2xl font-semibold tracking-tight text-slate-900">This month and next</h2>
                </div>
                <span class="rounded-full border border-purple-200 bg-purple-50 px-3 py-1 text-xs font-semibold text-purple-600">
                  Debt payments excluded
                </span>
              </div>

              <div class="mt-5 grid gap-3 md:grid-cols-2">
                <.month_card title="Current month" month={@health.current_month} />
                <.month_card title="Projected next month" month={@health.next_month} />
              </div>

              <div :if={@health.warnings != []} class="mt-5 rounded-2xl border border-amber-200 bg-amber-50/80 p-4">
                <p class="text-xs font-semibold uppercase tracking-wide text-amber-700">Insights</p>
                <ul class="mt-2 space-y-1 text-sm text-amber-900">
                  <li :for={warning <- @health.warnings}><%= warning %></li>
                </ul>
              </div>
            </div>

            <div class="rounded-[2rem] border border-purple-100 bg-white/85 p-6 shadow-[0_30px_80px_-45px_rgba(109,40,217,0.35)]">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Health status</p>
              <div class="mt-5 space-y-4">
                <.status_row label="Debt-to-income" value={"#{@health.debt_to_income_ratio}%"} />
                <.status_row label="Minimum burden" value={"#{@health.minimum_payment_burden}%"} />
                <.status_row label="Monthly minimums" value={money(@health.minimum_debt_payment)} />
              </div>
            </div>
          </section>

          <section class="mt-5 grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
            <div class="rounded-[2rem] border border-purple-100 bg-white/85 p-6 shadow-[0_30px_80px_-45px_rgba(109,40,217,0.35)]">
              <div class="flex items-center justify-between gap-4">
                <div>
                  <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Manual debts</p>
                  <h2 class="mt-2 text-2xl font-semibold tracking-tight text-slate-900">Balances</h2>
                </div>
                <button type="button" phx-click="open_debt_form" class="btn btn-secondary btn-xs">Add</button>
              </div>

              <.form
                :if={@debt_form_open}
                for={@debt_form}
                phx-submit="create_debt"
                class="mt-5 rounded-2xl border border-purple-100 bg-purple-50/70 p-4"
              >
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
                <div :if={@debts == []} class="rounded-2xl border border-dashed border-purple-200 bg-white/70 p-5 text-sm text-slate-500">
                  Add debts to compare payoff strategies.
                </div>

                <div :for={debt <- @debts} class="rounded-2xl border border-purple-100 bg-white p-4 shadow-sm">
                  <div class="flex items-start justify-between gap-4">
                    <div>
                      <p class="font-semibold text-slate-900"><%= debt.name %></p>
                      <p class="mt-1 text-xs text-slate-500">
                        <%= format_kind(debt.kind) %><%= if debt.provider, do: " with #{debt.provider}" %>
                      </p>
                    </div>
                    <button type="button" phx-click="archive_debt" phx-value-id={debt.id} class="btn btn-ghost btn-xs text-rose-600">
                      Archive
                    </button>
                  </div>
                  <div class="mt-4 grid grid-cols-3 gap-3 text-sm">
                    <div>
                      <p class="text-[11px] font-semibold uppercase tracking-wide text-slate-400">Balance</p>
                      <p class="mt-1 font-semibold text-slate-900"><%= money(debt.current_balance) %></p>
                    </div>
                    <div>
                      <p class="text-[11px] font-semibold uppercase tracking-wide text-slate-400">Minimum</p>
                      <p class="mt-1 font-semibold text-slate-900"><%= money(debt.minimum_payment) %></p>
                    </div>
                    <div>
                      <p class="text-[11px] font-semibold uppercase tracking-wide text-slate-400">APR</p>
                      <p class="mt-1 font-semibold text-slate-900"><%= apr(debt.apr) %></p>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div class="rounded-[2rem] border border-purple-100 bg-white/85 p-6 shadow-[0_30px_80px_-45px_rgba(109,40,217,0.35)]">
              <div class="flex flex-wrap items-center justify-between gap-4">
                <div>
                  <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Payoff comparison</p>
                  <h2 class="mt-2 text-2xl font-semibold tracking-tight text-slate-900">Snowball vs avalanche</h2>
                </div>
                <button type="button" phx-click="generate_plans" class="btn btn-primary btn-xs">Refresh</button>
              </div>

              <div class="mt-5 grid gap-4 lg:grid-cols-2">
                <.plan_card :for={plan <- @comparison} plan={plan} />
                <div :if={@comparison == []} class="rounded-2xl border border-dashed border-purple-200 bg-white/70 p-5 text-sm text-slate-500 lg:col-span-2">
                  Generate plans to compare payoff order, payoff month, and estimated interest.
                </div>
              </div>

              <div class="mt-6">
                <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">Saved plans</p>
                <div class="mt-3 space-y-2">
                  <div :if={@plans == []} class="rounded-2xl border border-purple-100 bg-purple-50/60 p-4 text-sm text-slate-500">
                    No saved payoff plans yet.
                  </div>
                  <div :for={plan <- @plans} class="flex items-center justify-between gap-4 rounded-2xl border border-purple-100 bg-white p-4">
                    <div>
                      <p class="font-semibold text-slate-900"><%= plan.name %></p>
                      <p class="mt-1 text-xs text-slate-500">
                        <%= String.capitalize(plan.strategy) %> · <%= money(plan.monthly_amount) %>/mo
                      </p>
                    </div>
                    <span class="text-xs font-semibold text-purple-600"><%= format_date(plan.target_payoff_date) %></span>
                  </div>
                </div>
              </div>
            </div>
          </section>
        </main>
      </div>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :accent, :string, default: "text-slate-900"

  defp metric_card(assigns) do
    ~H"""
    <div class="rounded-[1.5rem] border border-purple-100 bg-white/85 p-5 shadow-sm">
      <p class="text-[11px] font-semibold uppercase tracking-wide text-slate-400"><%= @label %></p>
      <p class={["mt-3 text-2xl font-semibold tracking-tight", @accent]}><%= @value %></p>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :month, :map, required: true

  defp month_card(assigns) do
    ~H"""
    <div class="rounded-2xl border border-purple-100 bg-white p-5">
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
  attr :value, :string, required: true

  defp status_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-4">
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
        class="w-full rounded-xl border border-purple-100 bg-white px-4 py-3 text-sm text-slate-900 outline-none transition focus:border-purple-300 focus:ring-2 focus:ring-purple-200"
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
        class="w-full rounded-xl border border-purple-100 bg-white px-4 py-3 text-sm text-slate-900 outline-none transition focus:border-purple-300 focus:ring-2 focus:ring-purple-200"
      >
        <option :for={{label, value} <- @options} value={value} selected={to_string(@field_data.value || "") == value}>
          <%= label %>
        </option>
      </select>
    </div>
    """
  end

  attr :plan, :map, required: true

  defp plan_card(assigns) do
    ~H"""
    <div class="rounded-2xl border border-purple-100 bg-white p-5 shadow-sm">
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

      <div class="mt-4 rounded-xl bg-purple-50/70 p-3">
        <p class="text-[11px] font-semibold uppercase tracking-wide text-purple-500">Order</p>
        <p class="mt-1 text-sm text-slate-700"><%= payoff_order(@plan.payoff_order) %></p>
      </div>
    </div>
    """
  end

  defp assign_finance_data(socket) do
    user = socket.assigns.current_scope.user

    assign(socket,
      debts: Finance.list_debts_for_user(user),
      health: Finance.get_financial_health(user),
      plans: Finance.list_payoff_plans_for_user(user)
    )
  end

  defp assign_debt_form(socket) do
    assign(socket, debt_form: to_form(Finance.change_debt(), as: :debt))
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

  defp money(%Decimal{} = amount), do: "$#{Decimal.round(amount, 2)}"
  defp money(nil), do: "$0.00"

  defp apr(nil), do: "Missing"
  defp apr(%Decimal{} = value), do: "#{Decimal.round(value, 2)}%"

  defp format_date(nil), do: "Not set"
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%b %-d, %Y")

  defp format_kind(kind), do: kind |> String.replace("_", " ") |> String.capitalize()

  defp payoff_order([]), do: "No active balances"
  defp payoff_order(debts), do: debts |> Enum.map(& &1.name) |> Enum.join(" -> ")

  defp translate_error({message, opts}) do
    Enum.reduce(opts, message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end

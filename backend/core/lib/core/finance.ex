defmodule Core.Finance do
  @moduledoc """
  The Finance context - Manages all financial transactions and budgets.
  """

  @default_currency "DOP"

  import Ecto.Query, warn: false
  alias Core.Accounts
  alias Core.Accounts.{Household, User}
  alias Core.Repo

  alias Core.Finance.{
    Account,
    Budget,
    Category,
    Debt,
    DebtPayment,
    DebtPayoffPlan,
    DebtPlanner,
    EmailIngestion,
    EmailIngestionAttempt,
    Health,
    Transaction
  }

  # ------ Transactions ------

  def list_transactions(%User{} = actor, owner, opts \\ []) when is_list(opts) do
    with :ok <- ensure_scope_access(actor, owner) do
      {:ok, do_list_transactions(owner, opts)}
    end
  end

  def list_transactions_for_user(%User{} = user, opts \\ []) do
    do_list_transactions(user, opts)
  end

  def list_user_transactions(user_id, opts \\ []) do
    do_list_transactions(%User{id: user_id}, opts)
  end

  defp apply_transaction_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:type, type}, query ->
        where(query, [t], t.type == ^type)

      {:status, statuses}, query when is_list(statuses) ->
        where(query, [t], t.status in ^statuses)

      {:status, status}, query ->
        where(query, [t], t.status == ^status)

      {:source, sources}, query when is_list(sources) ->
        where(query, [t], t.source in ^sources)

      {:source, source}, query ->
        where(query, [t], t.source == ^source)

      {:category_id, category_id}, query ->
        where(query, [t], t.category_id == ^category_id)

      {:start_date, start_date}, query ->
        where(query, [t], t.transaction_date >= ^start_date)

      {:end_date, end_date}, query ->
        where(query, [t], t.transaction_date <= ^end_date)

      {:limit, limit}, query ->
        limit(query, ^limit)

      _, query ->
        query
    end)
  end

  defp do_list_transactions(owner, opts) do
    query =
      Transaction
      |> scope_query(owner)
      |> order_by([t], desc: t.transaction_date, desc: t.inserted_at)
      |> preload([:category, :account])

    query = apply_transaction_filters(query, opts)
    Repo.all(query)
  end

  def list_pending_transactions_for_user(%User{} = user, opts \\ []) do
    user
    |> list_transactions_for_user(Keyword.put(opts, :status, "pending_review"))
  end

  def list_pending_transactions(%User{} = actor, owner, opts \\ []) do
    list_transactions(actor, owner, Keyword.put(opts, :status, "pending_review"))
  end

  @doc """
  Gets a single transaction.
  """
  def get_transaction!(id) do
    Transaction
    |> preload([:user, :category, :account])
    |> Repo.get!(id)
  end

  def get_transaction_for_user!(%User{} = user, id) do
    Transaction
    |> where([transaction], transaction.user_id == ^user.id)
    |> preload([:user, :category, :account])
    |> Repo.get!(id)
  end

  def get_transaction!(%User{} = actor, owner, id) do
    with :ok <- ensure_scope_access(actor, owner) do
      Transaction
      |> scope_query(owner)
      |> preload([:user, :household, :category, :account])
      |> Repo.get!(id)
    end
  end

  @doc """
  Creates a transaction
  """
  def create_transaction(%User{} = user, attrs \\ %{}) do
    create_transaction(user, user, attrs)
  end

  def create_transaction(%User{} = actor, owner, attrs) do
    with :ok <- ensure_scope_access(actor, owner),
         attrs <- scope_attrs(attrs, owner),
         :ok <- ensure_category_in_scope(attrs, owner),
         :ok <- ensure_account_in_scope(attrs, owner) do
      %Transaction{}
      |> Transaction.changeset(attrs)
      |> Repo.insert()
    end
  end

  def change_transaction(%Transaction{} = transaction \\ %Transaction{}) do
    Transaction.changeset(transaction, %{})
  end

  def ingest_email_transaction_candidate(%User{} = user, attrs) do
    EmailIngestion.ingest(user, attrs)
  end

  def list_email_ingestions_for_user(%User{} = user, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)

    EmailIngestionAttempt
    |> where([attempt], attempt.user_id == ^user.id)
    |> order_by([attempt], desc: attempt.inserted_at)
    |> limit(^limit)
    |> preload(:transaction)
    |> Repo.all()
  end

  @doc """
  Updates a transaction
  """
  def update_transaction(%User{} = user, %Transaction{} = transaction, attrs) do
    with :ok <- ensure_resource_owner(user, transaction) do
      with :ok <- ensure_category_in_scope(attrs, resource_owner(transaction)),
           :ok <- ensure_account_in_scope(attrs, resource_owner(transaction)) do
        update_transaction(transaction, attrs)
      end
    end
  end

  def update_transaction(%Transaction{} = transaction, attrs) do
    transaction
    |> Transaction.changeset(attrs)
    |> Repo.update()
  end

  def confirm_transaction(%User{} = user, %Transaction{} = transaction, attrs \\ %{}) do
    with :ok <- ensure_resource_owner(user, transaction) do
      transaction
      |> Transaction.changeset(
        Map.merge(attrs, %{"status" => "confirmed", "review_reason" => nil})
      )
      |> Repo.update()
    end
  end

  def ignore_transaction(%User{} = user, %Transaction{} = transaction) do
    with :ok <- ensure_resource_owner(user, transaction) do
      transaction
      |> Transaction.changeset(%{"status" => "ignored"})
      |> Repo.update()
    end
  end

  @doc """
  Deletes a transaction
  """
  def delete_transaction(%User{} = user, %Transaction{} = transaction) do
    with :ok <- ensure_resource_owner(user, transaction) do
      delete_transaction(transaction)
    end
  end

  def delete_transaction(%Transaction{} = transaction) do
    Repo.delete(transaction)
  end

  @doc """
  Calculates total income for a user in a date range
  """
  def calculate_total_income(%User{} = user, start_date, end_date) do
    calculate_total_income_for_scope(user, start_date, end_date)
  end

  def calculate_total_income(owner, start_date, end_date) do
    calculate_total_income_for_scope(owner, start_date, end_date)
  end

  defp calculate_total_income_for_scope(owner, start_date, end_date) do
    Transaction
    |> scope_query(owner)
    |> where([t], t.status == "confirmed")
    |> where([t], t.type == "income")
    |> where([t], t.transaction_date >= ^start_date and t.transaction_date <= ^end_date)
    |> select([t], sum(t.amount))
    |> Repo.one() || Decimal.new(0)
  end

  @doc """
  Calculates total expenses for a user in a date range
  """
  def calculate_total_expenses(%User{} = user, start_date, end_date) do
    calculate_total_expenses_for_scope(user, start_date, end_date)
  end

  def calculate_total_expenses(owner, start_date, end_date) do
    calculate_total_expenses_for_scope(owner, start_date, end_date)
  end

  defp calculate_total_expenses_for_scope(owner, start_date, end_date) do
    Transaction
    |> scope_query(owner)
    |> where([t], t.status == "confirmed")
    |> where([t], t.type == "expense")
    |> where([t], t.transaction_date >= ^start_date and t.transaction_date <= ^end_date)
    |> select([t], sum(t.amount))
    |> Repo.one() || Decimal.new(0)
  end

  @doc """
  Gets financial summary for a user
  """
  def get_financial_summary(%User{} = user, start_date, end_date) do
    get_financial_summary_for_scope(user, start_date, end_date)
  end

  def get_financial_summary(owner, start_date, end_date) do
    get_financial_summary_for_scope(owner, start_date, end_date)
  end

  def get_currency_summary(owner, start_date, end_date, opts \\ []) do
    statuses = Keyword.get(opts, :statuses, ["confirmed"])
    exclude_debt_payment_expenses = Keyword.get(opts, :exclude_debt_payment_expenses, false)

    rows =
      Transaction
      |> scope_query(owner)
      |> join(:left, [transaction], account in assoc(transaction, :account))
      |> where([transaction, _account], transaction.status in ^statuses)
      |> where(
        [transaction, _account],
        transaction.transaction_date >= ^start_date and transaction.transaction_date <= ^end_date
      )
      |> maybe_exclude_debt_payment_expenses(owner, exclude_debt_payment_expenses)
      |> group_by([transaction, account], [account.currency, transaction.type])
      |> select([transaction, account], %{
        currency: fragment("COALESCE(?, ?)", account.currency, ^@default_currency),
        type: transaction.type,
        amount: sum(transaction.amount)
      })
      |> Repo.all()

    income = currency_totals_for_type(rows, "income")
    expenses = currency_totals_for_type(rows, "expense")

    %{
      income: income,
      expenses: expenses,
      balance: subtract_currency_totals(income, expenses),
      start_date: start_date,
      end_date: end_date
    }
  end

  defp get_financial_summary_for_scope(owner, start_date, end_date) do
    income = calculate_total_income(owner, start_date, end_date)
    expenses = calculate_total_expenses(owner, start_date, end_date)
    balance = Decimal.sub(income, expenses)

    %{
      income: income,
      expenses: expenses,
      balance: balance,
      start_date: start_date,
      end_date: end_date
    }
  end

  # ------ Categories ------

  # ------ Accounts ------

  def list_accounts(%User{} = actor, owner) do
    with :ok <- ensure_scope_access(actor, owner) do
      {:ok, do_list_accounts(owner)}
    end
  end

  def list_accounts_for_user(%User{} = user) do
    do_list_accounts(user)
  end

  defp do_list_accounts(owner) do
    Account
    |> scope_query(owner)
    |> where([account], account.status == "active")
    |> order_by([account], asc: account.kind, asc: account.name)
    |> Repo.all()
  end

  def get_account!(%User{} = actor, owner, id) do
    with :ok <- ensure_scope_access(actor, owner) do
      Account
      |> scope_query(owner)
      |> Repo.get!(id)
    end
  end

  def create_account(%User{} = user, attrs \\ %{}) do
    create_account(user, user, attrs)
  end

  def create_account(%User{} = actor, owner, attrs) do
    with :ok <- ensure_scope_access(actor, owner),
         attrs <- scope_attrs(attrs, owner) do
      %Account{}
      |> Account.changeset(attrs)
      |> Repo.insert()
    end
  end

  def change_account(%Account{} = account \\ %Account{}) do
    Account.changeset(account, %{})
  end

  def list_account_summaries(%User{} = actor, owner, start_date, end_date) do
    with :ok <- ensure_scope_access(actor, owner) do
      accounts = do_list_accounts(owner)

      totals =
        Transaction
        |> scope_query(owner)
        |> where([transaction], not is_nil(transaction.account_id))
        |> where(
          [transaction],
          transaction.transaction_date >= ^start_date and
            transaction.transaction_date <= ^end_date
        )
        |> group_by([transaction], transaction.account_id)
        |> select([transaction], %{
          account_id: transaction.account_id,
          income:
            fragment(
              "COALESCE(SUM(CASE WHEN ? = 'income' AND ? = 'confirmed' THEN ? ELSE 0 END), 0)",
              transaction.type,
              transaction.status,
              transaction.amount
            ),
          expenses:
            fragment(
              "COALESCE(SUM(CASE WHEN ? = 'expense' AND ? = 'confirmed' THEN ? ELSE 0 END), 0)",
              transaction.type,
              transaction.status,
              transaction.amount
            ),
          transaction_count: count(transaction.id)
        })
        |> Repo.all()
        |> Map.new(fn row -> {row.account_id, row} end)

      {:ok,
       Enum.map(accounts, fn account ->
         totals_row =
           Map.get(totals, account.id, %{
             income: Decimal.new("0"),
             expenses: Decimal.new("0"),
             transaction_count: 0
           })

         %{
           account: account,
           income: totals_row.income,
           expenses: totals_row.expenses,
           net: Decimal.sub(totals_row.income, totals_row.expenses),
           transaction_count: totals_row.transaction_count
         }
       end)}
    end
  end

  @doc """
  Returns the list of categories for a user
  """
  def list_categories_for_user(%User{} = user, type \\ nil) do
    do_list_categories(user, type)
  end

  def list_user_categories(user_id, type \\ nil) do
    do_list_categories(%User{id: user_id}, type)
  end

  def list_categories(%User{} = actor, owner, type \\ nil) do
    with :ok <- ensure_scope_access(actor, owner) do
      {:ok, do_list_categories(owner, type)}
    end
  end

  defp do_list_categories(owner, type) do
    query =
      Category
      |> scope_query(owner)
      |> order_by([c], asc: c.name)

    query = if type, do: where(query, [c], c.type == ^type), else: query
    Repo.all(query)
  end

  @doc """
  Gets a single category
  """
  def get_category!(id), do: Repo.get(Category, id)

  def get_category_for_user!(%User{} = user, id) do
    Category
    |> where([category], category.user_id == ^user.id)
    |> Repo.get!(id)
  end

  def get_category!(%User{} = actor, owner, id) do
    with :ok <- ensure_scope_access(actor, owner) do
      Category
      |> scope_query(owner)
      |> Repo.get!(id)
    end
  end

  @doc """
  Creates a category
  """
  def create_category(%User{} = user, attrs \\ %{}) do
    create_category(user, user, attrs)
  end

  def create_category(%User{} = actor, owner, attrs) do
    with :ok <- ensure_scope_access(actor, owner),
         attrs <- scope_attrs(attrs, owner) do
      %Category{}
      |> Category.changeset(attrs)
      |> Repo.insert()
    end
  end

  def change_category(%Category{} = category \\ %Category{}) do
    Category.changeset(category, %{})
  end

  @doc """
  Updates a category
  """
  def update_category(%User{} = user, %Category{} = category, attrs) do
    with :ok <- ensure_resource_owner(user, category) do
      update_category(category, attrs)
    end
  end

  def update_category(%Category{} = category, attrs) do
    category
    |> Category.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a category
  """
  def delete_category(%User{} = user, %Category{} = category) do
    with :ok <- ensure_resource_owner(user, category) do
      delete_category(category)
    end
  end

  def delete_category(%Category{} = category) do
    Repo.delete(category)
  end

  # ------ Budgets ------

  @doc """
  Returns the list of budgets for a user
  """
  def list_budgets_for_user(%User{} = user) do
    do_list_budgets(user)
  end

  def list_user_budgets(user_id) do
    do_list_budgets(%User{id: user_id})
  end

  def list_budgets(%User{} = actor, owner) do
    with :ok <- ensure_scope_access(actor, owner) do
      {:ok, do_list_budgets(owner)}
    end
  end

  defp do_list_budgets(owner) do
    Budget
    |> scope_query(owner)
    |> where([b], b.is_active == true)
    |> order_by([b], desc: b.inserted_at)
    |> preload(:category)
    |> Repo.all()
  end

  @doc """
  Gets a single budget
  """
  def get_budget!(id) do
    Budget
    |> preload([:user, :category])
    |> Repo.get!(id)
  end

  def get_budget_for_user!(%User{} = user, id) do
    Budget
    |> where([budget], budget.user_id == ^user.id)
    |> preload([:user, :category])
    |> Repo.get!(id)
  end

  def get_budget!(%User{} = actor, owner, id) do
    with :ok <- ensure_scope_access(actor, owner) do
      Budget
      |> scope_query(owner)
      |> preload([:user, :household, :category, :account])
      |> Repo.get!(id)
    end
  end

  @doc """
  Creates a budget
  """
  def create_budget(%User{} = user, attrs \\ %{}) do
    create_budget(user, user, attrs)
  end

  def create_budget(%User{} = actor, owner, attrs) do
    with :ok <- ensure_scope_access(actor, owner),
         attrs <- scope_attrs(attrs, owner),
         :ok <- ensure_category_in_scope(attrs, owner) do
      %Budget{}
      |> Budget.changeset(attrs)
      |> Repo.insert()
    end
  end

  def change_budget(%Budget{} = budget \\ %Budget{}) do
    Budget.changeset(budget, %{})
  end

  def list_budget_statuses_for_user(%User{} = user) do
    user
    |> list_budgets_for_user()
    |> Enum.map(&check_budget_status/1)
  end

  def list_budget_statuses(%User{} = actor, owner) do
    with {:ok, budgets} <- list_budgets(actor, owner) do
      {:ok, Enum.map(budgets, &check_budget_status/1)}
    end
  end

  @doc """
  Updates a budget
  """
  def update_budget(%User{} = user, %Budget{} = budget, attrs) do
    with :ok <- ensure_resource_owner(user, budget) do
      with :ok <- ensure_category_in_scope(attrs, resource_owner(budget)) do
        update_budget(budget, attrs)
      end
    end
  end

  def update_budget(%Budget{} = budget, attrs) do
    budget
    |> Budget.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a budget
  """
  def delete_budget(%User{} = user, %Budget{} = budget) do
    with :ok <- ensure_resource_owner(user, budget) do
      delete_budget(budget)
    end
  end

  def delete_budget(%Budget{} = budget), do: Repo.delete(budget)

  # ------ Debts ------

  def list_debts_for_user(%User{} = user) do
    do_list_debts(user)
  end

  def list_debts(%User{} = actor, owner) do
    with :ok <- ensure_scope_access(actor, owner) do
      {:ok, do_list_debts(owner)}
    end
  end

  defp do_list_debts(owner) do
    Debt
    |> scope_query(owner)
    |> where([debt], debt.status == "active")
    |> order_by([debt], asc: debt.current_balance, asc: debt.name)
    |> preload(payments: ^recent_debt_payments_query())
    |> Repo.all()
  end

  def get_debt_for_user!(%User{} = user, id) do
    Debt
    |> where([debt], debt.user_id == ^user.id)
    |> preload(payments: ^recent_debt_payments_query())
    |> Repo.get!(id)
  end

  def get_debt!(%User{} = actor, owner, id) do
    with :ok <- ensure_scope_access(actor, owner) do
      Debt
      |> scope_query(owner)
      |> preload(payments: ^recent_debt_payments_query())
      |> Repo.get!(id)
    end
  end

  def change_debt(%Debt{} = debt \\ %Debt{}) do
    Debt.changeset(debt, %{})
  end

  def create_debt(%User{} = user, attrs \\ %{}) do
    create_debt(user, user, attrs)
  end

  def create_debt(%User{} = actor, owner, attrs) do
    with :ok <- ensure_scope_access(actor, owner),
         attrs <- scope_attrs(attrs, owner) do
      %Debt{}
      |> Debt.changeset(attrs)
      |> Repo.insert()
    end
  end

  def update_debt(%User{} = user, %Debt{} = debt, attrs) do
    with :ok <- ensure_resource_owner(user, debt) do
      debt
      |> Debt.changeset(attrs)
      |> Repo.update()
    end
  end

  def delete_debt(%User{} = user, %Debt{} = debt) do
    with :ok <- ensure_resource_owner(user, debt) do
      debt
      |> Debt.changeset(%{"status" => "archived"})
      |> Repo.update()
    end
  end

  def change_debt_payment(%DebtPayment{} = payment \\ %DebtPayment{}) do
    DebtPayment.changeset(payment, %{})
  end

  def list_debt_payments_for_user(%User{} = user, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)

    DebtPayment
    |> where([payment], payment.user_id == ^user.id)
    |> order_by([payment], desc: payment.payment_date, desc: payment.inserted_at)
    |> limit(^limit)
    |> preload([:debt, :transaction])
    |> Repo.all()
  end

  def list_debt_payments_for_debt(%User{} = user, %Debt{} = debt) do
    with :ok <- ensure_resource_owner(user, debt) do
      owner = resource_owner(debt)

      DebtPayment
      |> scope_query(owner)
      |> where([payment], payment.debt_id == ^debt.id)
      |> order_by([payment], desc: payment.payment_date, desc: payment.inserted_at)
      |> preload(:transaction)
      |> Repo.all()
    end
  end

  def record_debt_payment(%User{} = user, %Debt{} = debt, attrs \\ %{}) do
    with :ok <- ensure_resource_owner(user, debt) do
      owner = resource_owner(debt)

      changeset =
        %DebtPayment{debt_id: debt.id}
        |> DebtPayment.changeset(scope_attrs(attrs, owner))
        |> validate_debt_payment_amount(debt)

      if changeset.valid? do
        Repo.transaction(fn ->
          transaction = maybe_create_debt_payment_transaction!(user, debt, attrs, changeset)
          payment = insert_debt_payment!(changeset, transaction)
          update_debt_after_payment!(debt, payment)
          payment
        end)
      else
        {:error, changeset}
      end
    end
  end

  def delete_debt_payment(%User{} = user, %DebtPayment{} = payment) do
    with :ok <- ensure_resource_owner(user, payment) do
      Repo.delete(payment)
    end
  end

  def list_payoff_plans_for_user(%User{} = user) do
    do_list_payoff_plans(user)
  end

  def list_payoff_plans(%User{} = actor, owner) do
    with :ok <- ensure_scope_access(actor, owner) do
      {:ok, do_list_payoff_plans(owner)}
    end
  end

  defp do_list_payoff_plans(owner) do
    DebtPayoffPlan
    |> scope_query(owner)
    |> where([plan], plan.status == "active")
    |> order_by([plan], desc: plan.inserted_at)
    |> Repo.all()
  end

  def generate_debt_payoff_comparison(%User{} = user, opts \\ []) do
    today = Keyword.get(opts, :today, Date.utc_today())
    starts_on = Keyword.get(opts, :starts_on, Date.beginning_of_month(today))
    health = get_financial_health(user, today: today)
    monthly_amount = Keyword.get(opts, :monthly_amount, health.current_month.free_cash_flow)

    user
    |> list_debts_for_user()
    |> DebtPlanner.compare(monthly_amount, starts_on)
  end

  def generate_debt_payoff_comparison(%User{} = actor, owner, opts) do
    with :ok <- ensure_scope_access(actor, owner) do
      today = Keyword.get(opts, :today, Date.utc_today())
      starts_on = Keyword.get(opts, :starts_on, Date.beginning_of_month(today))
      health = get_financial_health(actor, owner, today: today)
      monthly_amount = Keyword.get(opts, :monthly_amount, health.current_month.free_cash_flow)

      owner
      |> do_list_debts()
      |> DebtPlanner.compare(monthly_amount, starts_on)
    end
  end

  def save_debt_payoff_plan(%User{} = user, attrs) do
    save_debt_payoff_plan(user, user, attrs)
  end

  def save_debt_payoff_plan(%User{} = actor, owner, attrs) do
    with :ok <- ensure_scope_access(actor, owner),
         attrs <- scope_attrs(attrs, owner) do
      %DebtPayoffPlan{}
      |> DebtPayoffPlan.changeset(attrs)
      |> Repo.insert()
    end
  end

  def save_generated_debt_payoff_plan(%User{} = user, plan) do
    save_debt_payoff_plan(user, %{
      "name" => "#{String.capitalize(plan.strategy)} payoff plan",
      "strategy" => plan.strategy,
      "monthly_amount" => plan.monthly_amount,
      "starts_on" => Date.beginning_of_month(Date.utc_today()),
      "target_payoff_date" => plan.target_payoff_date,
      "snapshot" => stringify_plan(plan)
    })
  end

  def save_generated_debt_payoff_plan(%User{} = actor, owner, plan) do
    save_debt_payoff_plan(actor, owner, %{
      "name" => "#{String.capitalize(plan.strategy)} payoff plan",
      "strategy" => plan.strategy,
      "monthly_amount" => plan.monthly_amount,
      "starts_on" => Date.beginning_of_month(Date.utc_today()),
      "target_payoff_date" => plan.target_payoff_date,
      "snapshot" => stringify_plan(plan)
    })
  end

  def get_financial_health(%User{} = user, opts \\ []) do
    today = Keyword.get(opts, :today, Date.utc_today())

    current_month =
      month_summary(user, Date.beginning_of_month(today), Date.end_of_month(today))

    next_month_start = today |> Date.end_of_month() |> Date.add(1)
    next_month_end = Date.end_of_month(next_month_start)

    next_month =
      current_month
      |> project_next_month(today, next_month_start, next_month_end)

    Health.build(current_month, next_month, list_debts_for_user(user))
  end

  def get_financial_health(%User{} = actor, owner, opts) do
    with :ok <- ensure_scope_access(actor, owner) do
      today = Keyword.get(opts, :today, Date.utc_today())

      current_month =
        month_summary(owner, Date.beginning_of_month(today), Date.end_of_month(today))

      next_month_start = today |> Date.end_of_month() |> Date.add(1)
      next_month_end = Date.end_of_month(next_month_start)

      next_month =
        current_month
        |> project_next_month(today, next_month_start, next_month_end)

      Health.build(current_month, next_month, do_list_debts(owner))
    end
  end

  @doc """
  Checks budget status and returns spending %
  """
  def check_budget_status(%Budget{} = budget) do
    budget_currency = normalize_currency(budget.currency)

    spent =
      Transaction
      |> scope_query(resource_owner(budget))
      |> join(:left, [transaction], account in assoc(transaction, :account))
      |> where([t], t.status == "confirmed")
      |> where([t], t.type == "expense")
      |> where([t], t.transaction_date >= ^budget.start_date)
      |> maybe_filter_by_end_date(budget.end_date)
      |> maybe_filter_by_category(budget.category_id)
      |> where(
        [_transaction, account],
        fragment("COALESCE(?, ?)", account.currency, ^@default_currency) == ^budget_currency
      )
      |> select([transaction, _account], sum(transaction.amount))
      |> Repo.one() || Decimal.new(0)

    percentage =
      spent
      |> Decimal.div(budget.amount)
      |> Decimal.mult(100)
      |> Decimal.to_float()

    %{
      budget: budget,
      spent: spent,
      remaining: Decimal.sub(budget.amount, spent),
      percentage: percentage,
      is_over: percentage > 100,
      is_near_limit: percentage >= budget.alert_threshold
    }
  end

  defp maybe_filter_by_end_date(query, nil), do: query

  defp maybe_filter_by_end_date(query, end_date) do
    where(query, [t], t.transaction_date <= ^end_date)
  end

  defp maybe_filter_by_category(query, nil), do: query

  defp maybe_filter_by_category(query, category_id) do
    where(query, [t], t.category_id == ^category_id)
  end

  defp month_summary(owner, start_date, end_date) do
    income = sum_transactions(owner, "income", start_date, end_date)
    expenses = sum_transactions_excluding_debt_payments(owner, start_date, end_date)

    %{
      start_date: start_date,
      end_date: end_date,
      income: income,
      expenses: expenses
    }
  end

  defp project_next_month(current_month, today, next_month_start, next_month_end) do
    elapsed_days = max(today.day, 1)
    next_month_days = Date.diff(next_month_end, next_month_start) + 1

    %{
      start_date: next_month_start,
      end_date: next_month_end,
      income: project_amount(current_month.income, elapsed_days, next_month_days),
      expenses: project_amount(current_month.expenses, elapsed_days, next_month_days)
    }
  end

  defp project_amount(amount, elapsed_days, projected_days) do
    amount
    |> Decimal.div(Decimal.new(elapsed_days))
    |> Decimal.mult(Decimal.new(projected_days))
    |> Decimal.round(2)
  end

  defp sum_transactions(owner, type, start_date, end_date) do
    Transaction
    |> scope_query(owner)
    |> where([transaction], transaction.status == "confirmed")
    |> where([transaction], transaction.type == ^type)
    |> where(
      [transaction],
      transaction.transaction_date >= ^start_date and transaction.transaction_date <= ^end_date
    )
    |> select([transaction], sum(transaction.amount))
    |> Repo.one() || Decimal.new("0")
  end

  defp sum_transactions_excluding_debt_payments(owner, start_date, end_date) do
    debt_payment_transaction_ids =
      DebtPayment
      |> scope_query(owner)
      |> where([payment], not is_nil(payment.transaction_id))
      |> select([payment], payment.transaction_id)

    Transaction
    |> scope_query(owner)
    |> where([transaction], transaction.status == "confirmed")
    |> where([transaction], transaction.type == "expense")
    |> where(
      [transaction],
      transaction.transaction_date >= ^start_date and transaction.transaction_date <= ^end_date
    )
    |> where([transaction], transaction.id not in subquery(debt_payment_transaction_ids))
    |> select([transaction], sum(transaction.amount))
    |> Repo.one() || Decimal.new("0")
  end

  defp maybe_exclude_debt_payment_expenses(query, _owner, false), do: query

  defp maybe_exclude_debt_payment_expenses(query, owner, true) do
    debt_payment_transaction_ids =
      DebtPayment
      |> scope_query(owner)
      |> where([payment], not is_nil(payment.transaction_id))
      |> select([payment], payment.transaction_id)

    where(
      query,
      [transaction, _account],
      transaction.type != "expense" or
        transaction.id not in subquery(debt_payment_transaction_ids)
    )
  end

  defp currency_totals_for_type(rows, type) do
    rows
    |> Enum.filter(&(&1.type == type))
    |> Enum.map(fn row ->
      %{
        currency: normalize_currency(row.currency),
        amount: row.amount || Decimal.new("0")
      }
    end)
    |> sort_currency_totals()
  end

  defp subtract_currency_totals(left_totals, right_totals) do
    left_totals
    |> Enum.reduce(%{}, fn %{currency: currency, amount: amount}, acc ->
      Map.update(acc, currency, amount, &Decimal.add(&1, amount))
    end)
    |> then(fn totals ->
      Enum.reduce(right_totals, totals, fn %{currency: currency, amount: amount}, acc ->
        Map.update(acc, currency, Decimal.negate(amount), &Decimal.sub(&1, amount))
      end)
    end)
    |> Enum.map(fn {currency, amount} -> %{currency: currency, amount: amount} end)
    |> sort_currency_totals()
  end

  defp sort_currency_totals(totals) do
    Enum.sort_by(totals, fn %{currency: currency} ->
      {currency_sort_rank(currency), currency}
    end)
  end

  defp currency_sort_rank("DOP"), do: 0
  defp currency_sort_rank("USD"), do: 1
  defp currency_sort_rank(_currency), do: 2

  defp normalize_currency(nil), do: @default_currency

  defp normalize_currency(currency) do
    case currency |> to_string() |> String.trim() |> String.upcase() do
      "" -> @default_currency
      normalized -> normalized
    end
  end

  defp recent_debt_payments_query do
    from payment in DebtPayment,
      order_by: [desc: payment.payment_date, desc: payment.inserted_at],
      limit: 3,
      preload: [:transaction]
  end

  defp validate_debt_payment_amount(changeset, debt) do
    amount = Ecto.Changeset.get_field(changeset, :amount)
    kind = Ecto.Changeset.get_field(changeset, :kind)

    if amount && kind in ["minimum", "extra"] &&
         Decimal.compare(amount, debt.current_balance) == :gt do
      Ecto.Changeset.add_error(changeset, :amount, "cannot exceed current balance")
    else
      changeset
    end
  end

  defp maybe_create_debt_payment_transaction!(user, debt, attrs, changeset) do
    if create_expense_transaction?(attrs) do
      amount = Ecto.Changeset.get_field(changeset, :amount)
      payment_date = Ecto.Changeset.get_field(changeset, :payment_date)

      case create_transaction(user, resource_owner(debt), %{
             "amount" => amount,
             "type" => "expense",
             "description" => "Debt payment: #{debt.name}",
             "transaction_date" => payment_date,
             "notes" => Ecto.Changeset.get_field(changeset, :notes)
           }) do
        {:ok, transaction} -> transaction
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end
  end

  defp create_expense_transaction?(attrs) do
    value =
      Map.get(attrs, "create_expense_transaction") || Map.get(attrs, :create_expense_transaction)

    value in [true, "true", "on", "1", 1]
  end

  defp insert_debt_payment!(changeset, nil) do
    case Repo.insert(changeset) do
      {:ok, payment} -> payment
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp insert_debt_payment!(changeset, transaction) do
    changeset
    |> Ecto.Changeset.put_change(:transaction_id, transaction.id)
    |> Repo.insert()
    |> case do
      {:ok, payment} -> payment
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp update_debt_after_payment!(debt, payment) do
    balance =
      debt.current_balance
      |> Decimal.sub(payment.amount)
      |> max_decimal(Decimal.new("0"))

    attrs =
      if Decimal.compare(balance, Decimal.new("0")) == :eq do
        %{"current_balance" => balance, "status" => "paid_off"}
      else
        %{"current_balance" => balance}
      end

    case debt |> Debt.changeset(attrs) |> Repo.update() do
      {:ok, debt} -> debt
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp max_decimal(left, right),
    do: if(Decimal.compare(left, right) == :lt, do: right, else: left)

  defp stringify_plan(plan) do
    %{
      "strategy" => plan.strategy,
      "monthly_amount" => Decimal.to_string(plan.monthly_amount),
      "minimum_payment_total" => Decimal.to_string(plan.minimum_payment_total),
      "extra_payment" => Decimal.to_string(plan.extra_payment),
      "feasible" => plan.feasible?,
      "debt_count" => plan.debt_count,
      "starting_balance" => Decimal.to_string(plan.starting_balance),
      "estimated_interest" => Decimal.to_string(plan.estimated_interest),
      "payoff_months" => plan.payoff_months,
      "target_payoff_date" => plan.target_payoff_date && Date.to_iso8601(plan.target_payoff_date),
      "payoff_order" => Enum.map(plan.payoff_order, &Map.take(&1, [:id, :name])),
      "schedule" =>
        Enum.map(plan.schedule, fn entry ->
          %{
            "month" => entry.month,
            "date" => Date.to_iso8601(entry.date),
            "interest" => Decimal.to_string(entry.interest),
            "payment" => Decimal.to_string(entry.payment),
            "remaining_balance" => Decimal.to_string(entry.remaining_balance)
          }
        end)
    }
  end

  defp ensure_resource_owner(%User{} = user, resource) do
    cond do
      resource.user_id == user.id ->
        :ok

      resource.household_id ->
        if Accounts.user_household?(user, resource.household_id),
          do: :ok,
          else: {:error, :forbidden}

      true ->
        {:error, :forbidden}
    end
  end

  defp ensure_scope_access(%User{} = actor, %User{} = owner) do
    if actor.id == owner.id, do: :ok, else: {:error, :forbidden}
  end

  defp ensure_scope_access(%User{} = actor, %Household{} = owner) do
    if Accounts.user_household?(actor, owner.id), do: :ok, else: {:error, :forbidden}
  end

  defp scope_attrs(attrs, %User{} = owner) do
    attrs
    |> Map.new()
    |> Map.delete("household_id")
    |> Map.delete(:household_id)
    |> Map.put("user_id", owner.id)
    |> Map.put("household_id", nil)
  end

  defp scope_attrs(attrs, %Household{} = owner) do
    attrs
    |> Map.new()
    |> Map.delete("user_id")
    |> Map.delete(:user_id)
    |> Map.put("user_id", nil)
    |> Map.put("household_id", owner.id)
  end

  defp ensure_category_in_scope(attrs, owner) do
    case Map.get(attrs, "category_id") || Map.get(attrs, :category_id) do
      nil ->
        :ok

      "" ->
        :ok

      category_id ->
        category = Repo.get(Category, category_id)

        if category && same_scope?(owner, category) do
          :ok
        else
          {:error, :invalid_category_scope}
        end
    end
  end

  defp ensure_account_in_scope(attrs, owner) do
    case Map.get(attrs, "account_id") || Map.get(attrs, :account_id) do
      nil ->
        :ok

      "" ->
        :ok

      account_id ->
        account = Repo.get(Account, account_id)

        if account && same_scope?(owner, account) do
          :ok
        else
          {:error, :invalid_account_scope}
        end
    end
  end

  defp same_scope?(%User{id: owner_id}, %{user_id: owner_id, household_id: nil}), do: true
  defp same_scope?(%Household{id: owner_id}, %{household_id: owner_id, user_id: nil}), do: true
  defp same_scope?(_owner, _resource), do: false

  defp resource_owner(%{household_id: household_id}) when not is_nil(household_id),
    do: %Household{id: household_id}

  defp resource_owner(%{user_id: user_id}), do: %User{id: user_id}

  defp scope_query(query, %User{id: owner_id}) do
    where(query, [record], record.user_id == ^owner_id and is_nil(record.household_id))
  end

  defp scope_query(query, %Household{id: owner_id}) do
    where(query, [record], record.household_id == ^owner_id and is_nil(record.user_id))
  end
end

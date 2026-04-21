defmodule Core.Finance do
  @moduledoc """
  The Finance context - Manages all financial transactions and budgets.
  """

  import Ecto.Query, warn: false
  alias Core.Accounts.User
  alias Core.Repo

  alias Core.Finance.{Transaction, Budget, Category}

  # ------ Transactions ------

  def list_transactions_for_user(%User{} = user, opts \\ []) do
    do_list_transactions(user.id, opts)
  end

  def list_user_transactions(user_id, opts \\ []) do
    do_list_transactions(user_id, opts)
  end

  defp apply_transaction_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:type, type}, query ->
        where(query, [t], t.type == ^type)

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

  defp do_list_transactions(user_id, opts) do
    query =
      from t in Transaction,
        where: t.user_id == ^user_id,
        order_by: [desc: t.transaction_date, desc: t.inserted_at],
        preload: :category

    query = apply_transaction_filters(query, opts)
    Repo.all(query)
  end

  @doc """
  Gets a single transaction.
  """
  def get_transaction!(id) do
    Transaction
    |> preload([:user, :category])
    |> Repo.get!(id)
  end

  def get_transaction_for_user!(%User{} = user, id) do
    Transaction
    |> where([transaction], transaction.user_id == ^user.id)
    |> preload([:user, :category])
    |> Repo.get!(id)
  end

  @doc """
  Creates a transaction
  """
  def create_transaction(%User{} = user, attrs \\ %{}) do
    %Transaction{user_id: user.id}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a transaction
  """
  def update_transaction(%User{} = user, %Transaction{} = transaction, attrs) do
    with :ok <- ensure_resource_owner(user, transaction) do
      update_transaction(transaction, attrs)
    end
  end

  def update_transaction(%Transaction{} = transaction, attrs) do
    transaction
    |> Transaction.changeset(attrs)
    |> Repo.update()
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
    calculate_total_income(user.id, start_date, end_date)
  end

  def calculate_total_income(user_id, start_date, end_date) do
    Transaction
    |> where([t], t.user_id == ^user_id)
    |> where([t], t.type == "income")
    |> where([t], t.transaction_date >= ^start_date and t.transaction_date <= ^end_date)
    |> select([t], sum(t.amount))
    |> Repo.one() || Decimal.new(0)
  end

  @doc """
  Calculates total expenses for a user in a date range
  """
  def calculate_total_expenses(%User{} = user, start_date, end_date) do
    calculate_total_expenses(user.id, start_date, end_date)
  end

  def calculate_total_expenses(user_id, start_date, end_date) do
    Transaction
    |> where([t], t.user_id == ^user_id)
    |> where([t], t.type == "expense")
    |> where([t], t.transaction_date >= ^start_date and t.transaction_date <= ^end_date)
    |> select([t], sum(t.amount))
    |> Repo.one() || Decimal.new(0)
  end

  @doc """
  Gets financial summary for a user
  """
  def get_financial_summary(%User{} = user, start_date, end_date) do
    get_financial_summary(user.id, start_date, end_date)
  end

  def get_financial_summary(user_id, start_date, end_date) do
    income = calculate_total_income(user_id, start_date, end_date)
    expenses = calculate_total_expenses(user_id, start_date, end_date)
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

  @doc """
  Returns the list of categories for a user
  """
  def list_categories_for_user(%User{} = user, type \\ nil) do
    do_list_categories(user.id, type)
  end

  def list_user_categories(user_id, type \\ nil) do
    do_list_categories(user_id, type)
  end

  defp do_list_categories(user_id, type) do
    query =
      from c in Category,
        where: c.user_id == ^user_id,
        order_by: [asc: c.name]

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

  @doc """
  Creates a category
  """
  def create_category(%User{} = user, attrs \\ %{}) do
    %Category{user_id: user.id}
    |> Category.changeset(attrs)
    |> Repo.insert()
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
    do_list_budgets(user.id)
  end

  def list_user_budgets(user_id) do
    do_list_budgets(user_id)
  end

  defp do_list_budgets(user_id) do
    Budget
    |> where([b], b.user_id == ^user_id and b.is_active == true)
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

  @doc """
  Creates a budget
  """
  def create_budget(%User{} = user, attrs \\ %{}) do
    %Budget{user_id: user.id}
    |> Budget.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a budget
  """
  def update_budget(%User{} = user, %Budget{} = budget, attrs) do
    with :ok <- ensure_resource_owner(user, budget) do
      update_budget(budget, attrs)
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

  @doc """
  Checks budget status and returns spending %
  """
  def check_budget_status(%Budget{} = budget) do
    spent =
      Transaction
      |> where([t], t.user_id == ^budget.user_id)
      |> where([t], t.type == "expense")
      |> where([t], t.transaction_date >= ^budget.start_date)
      |> maybe_filter_by_end_date(budget.end_date)
      |> maybe_filter_by_category(budget.category_id)
      |> select([t], sum(t.amount))
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

  defp ensure_resource_owner(%User{} = user, resource) do
    if resource.user_id == user.id, do: :ok, else: {:error, :forbidden}
  end
end

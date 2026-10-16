defmodule Core.Finance do
  @moduledoc """
  Money for a user or a household: accounts, transactions, transfers, budgets,
  debts, payoff plans, savings goals and email-ingested transactions.

  Context: every record has exactly one owner (a user or a household).
  Functions taking `(actor, owner, ...)` check that `actor` may use that
  scope; `*_for_user` variants are the personal-scope shortcuts. Every
  successful write broadcasts `{:finance_changed, owner}` so open pages
  (Finance, the hub) reload; inside a transaction the outer function
  broadcasts once after commit.

  ## Example

      {:ok, account} = Finance.create_account(user, household, %{"name" => "Joint", "kind" => "checking"})
      {:ok, accounts} = Finance.list_accounts(user, household)
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
    SavingsGoal,
    Transaction,
    IngestionToken
  }

  # ------ Transactions ------

  @doc """
  Transactions in a scope. Filters: `:type`, `:status`, `:source`, `:category_id`,
  `:account_id`, `:start_date`, `:end_date`, `:exclude_transfers`, plus `:limit`,
  `:offset`, `:sort`. Scoped: `{:error, :forbidden}` unless `actor` can access
  `owner`.
  """
  def list_transactions(%User{} = actor, owner, opts \\ []) when is_list(opts) do
    with :ok <- ensure_scope_access(actor, owner) do
      {:ok, do_list_transactions(owner, opts)}
    end
  end

  @doc "Personal-scope `list_transactions/3` without the `{:ok, _}` wrapper."
  def list_transactions_for_user(%User{} = user, opts \\ []) do
    do_list_transactions(user, opts)
  end

  @doc "Like `list_transactions_for_user/2`, by user id."
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

      {:account_id, account_id}, query ->
        where(query, [t], t.account_id == ^account_id)

      {:start_date, start_date}, query ->
        where(query, [t], t.transaction_date >= ^start_date)

      {:end_date, end_date}, query ->
        where(query, [t], t.transaction_date <= ^end_date)

      {:limit, limit}, query ->
        limit(query, ^limit)

      {:offset, offset}, query ->
        offset(query, ^offset)

      {:exclude_transfers, true}, query ->
        where(query, [t], is_nil(t.counterpart_transaction_id))

      _, query ->
        query
    end)
  end

  @transaction_sort_fields [:transaction_date, :amount, :merchant]

  defp apply_transaction_sort(query, opts) do
    case Keyword.get(opts, :sort) do
      {field, direction} when field in @transaction_sort_fields and direction in [:asc, :desc] ->
        order_by(query, [t], [{^direction, field(t, ^field)}, desc: t.inserted_at])

      _ ->
        order_by(query, [t], desc: t.transaction_date, desc: t.inserted_at)
    end
  end

  defp do_list_transactions(owner, opts) do
    query =
      Transaction
      |> scope_query(owner)
      |> apply_transaction_sort(opts)
      |> preload([:category, :account])

    query = apply_transaction_filters(query, opts)
    Repo.all(query)
  end

  @doc "Counts transactions matching the filters; paging options are ignored. `{:ok, count}`."
  def count_transactions(%User{} = actor, owner, opts \\ []) when is_list(opts) do
    with :ok <- ensure_scope_access(actor, owner) do
      count =
        Transaction
        |> scope_query(owner)
        |> apply_transaction_filters(Keyword.drop(opts, [:limit, :offset, :sort]))
        |> Repo.aggregate(:count)

      {:ok, count}
    end
  end

  @doc "Personal transactions waiting for review (`pending_review`)."
  def list_pending_transactions_for_user(%User{} = user, opts \\ []) do
    user
    |> list_transactions_for_user(Keyword.put(opts, :status, "pending_review"))
  end

  @doc "Transactions waiting for review in a scope. `{:ok, list}`."
  def list_pending_transactions(%User{} = actor, owner, opts \\ []) do
    list_transactions(actor, owner, Keyword.put(opts, :status, "pending_review"))
  end

  @doc "A transaction by id with user, category and account; raises if missing. No scope check."
  def get_transaction!(id) do
    Transaction
    |> preload([:user, :category, :account])
    |> Repo.get!(id)
  end

  @doc "One of the user's personal transactions; raises if missing."
  def get_transaction_for_user!(%User{} = user, id) do
    Transaction
    |> where([transaction], transaction.user_id == ^user.id)
    |> preload([:user, :category, :account])
    |> Repo.get!(id)
  end

  @doc "A transaction in a scope; raises if missing."
  def get_transaction!(%User{} = actor, owner, id) do
    with :ok <- ensure_scope_access(actor, owner) do
      Transaction
      |> scope_query(owner)
      |> preload([:user, :household, :category, :account])
      |> Repo.get!(id)
    end
  end

  # ------ Live updates ------
  #
  # Every successful write broadcasts {:finance_changed, owner_ref} on its
  # owner's topic ("finance:user:<id>" or "finance:household:<id>"), so every
  # LiveView showing that owner's data (Finance, the hub's Finance card, a
  # household member's open tab) can reload. broadcast_from skips the writing
  # process, which refreshes itself. Writes nested in a Repo.transaction stay
  # silent; the outer function broadcasts once, after the commit.

  @pubsub Core.PubSub

  @doc "Subscribes the caller to the user's finance topic and each of their households'."
  def subscribe(%User{} = user) do
    Phoenix.PubSub.subscribe(@pubsub, owner_topic({:user, user.id}))

    user
    |> Accounts.list_households_for_user()
    |> Enum.each(&subscribe_household/1)
  end

  @doc "Subscribes to one household's topic (after creating it mid-session)."
  def subscribe_household(%Household{id: id}),
    do: Phoenix.PubSub.subscribe(@pubsub, owner_topic({:household, id}))

  @doc "Tells every member viewing a household to reload (rename, members, delete)."
  def notify_household_change(household_id) do
    Phoenix.PubSub.broadcast_from(
      @pubsub,
      self(),
      owner_topic({:household, household_id}),
      {:finance_changed, {:household, household_id}}
    )
  end

  @doc "Tells a user's open pages to reload for non-finance changes (e.g. invitations)."
  def notify_user_change(user_id) do
    Phoenix.PubSub.broadcast_from(
      @pubsub,
      self(),
      owner_topic({:user, user_id}),
      {:finance_changed, {:user, user_id}}
    )
  end

  defp owner_topic({:user, id}), do: "finance:user:#{id}"
  defp owner_topic({:household, id}), do: "finance:household:#{id}"

  defp broadcast_change({:ok, value} = result) do
    unless Repo.in_transaction?() do
      for owner_ref <- owner_refs(value) do
        Phoenix.PubSub.broadcast_from(
          @pubsub,
          self(),
          owner_topic(owner_ref),
          {:finance_changed, owner_ref}
        )
      end
    end

    result
  end

  defp broadcast_change(result), do: result

  # A transfer returns both legs, which may belong to different owners.
  defp owner_refs({first, second}), do: Enum.uniq(owner_refs(first) ++ owner_refs(second))
  defp owner_refs(value), do: value |> owner_ref() |> List.wrap()

  defp owner_ref(%{household_id: id}) when not is_nil(id), do: {:household, id}
  defp owner_ref(%{user_id: id}) when not is_nil(id), do: {:user, id}
  defp owner_ref(_value), do: nil

  @doc "Creates a personal transaction. See `create_transaction/3`."
  def create_transaction(%User{} = user, attrs \\ %{}) do
    create_transaction(user, user, attrs)
  end

  @doc """
  Creates a transaction in a scope and moves its account's balance. Scoped:
  `{:error, :forbidden}` unless `actor` can access `owner`.
  """
  def create_transaction(%User{} = actor, owner, attrs) do
    with :ok <- ensure_scope_access(actor, owner),
         attrs <- scope_attrs(attrs, owner),
         :ok <- ensure_category_in_scope(attrs, owner),
         :ok <- ensure_account_in_scope(attrs, owner) do
      %Transaction{}
      |> Transaction.changeset(attrs)
      |> Repo.insert()
      |> broadcast_change()
    end
  end

  @doc "A transaction changeset for forms."
  def change_transaction(%Transaction{} = transaction \\ %Transaction{}) do
    Transaction.changeset(transaction, %{})
  end

  @doc "Turns a parsed bank email into a pending transaction (see `EmailIngestion`)."
  def ingest_email_transaction_candidate(%User{} = user, attrs) do
    EmailIngestion.ingest(user, attrs)
  end

  @doc "The user's latest email ingestion attempts (`:limit`, default 25), newest first."
  def list_email_ingestions_for_user(%User{} = user, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)

    EmailIngestionAttempt
    |> where([attempt], attempt.user_id == ^user.id)
    |> order_by([attempt], desc: attempt.inserted_at)
    |> limit(^limit)
    |> preload(:transaction)
    |> Repo.all()
  end

  @doc "Edits a transaction; its category must belong to the same scope."
  def update_transaction(%User{} = user, %Transaction{} = transaction, attrs) do
    with :ok <- ensure_resource_owner(user, transaction) do
      with :ok <- ensure_category_in_scope(attrs, resource_owner(transaction)),
           :ok <- ensure_account_in_scope(attrs, resource_owner(transaction)) do
        update_transaction(transaction, attrs)
      end
    end
  end

  @doc "Edits a transaction without an access check (callers check first)."
  def update_transaction(%Transaction{} = transaction, attrs) do
    transaction
    |> Transaction.changeset(attrs)
    |> Repo.update()
    |> broadcast_change()
  end

  @doc "Confirms a reviewed transaction (optionally with edits), so it counts in totals."
  def confirm_transaction(%User{} = user, %Transaction{} = transaction, attrs \\ %{}) do
    with :ok <- ensure_resource_owner(user, transaction) do
      transaction
      |> Transaction.changeset(
        Map.merge(attrs, %{"status" => "confirmed", "review_reason" => nil})
      )
      |> Repo.update()
      |> broadcast_change()
    end
  end

  @doc "Marks a pending transaction as ignored."
  def ignore_transaction(%User{} = user, %Transaction{} = transaction) do
    with :ok <- ensure_resource_owner(user, transaction) do
      transaction
      |> Transaction.changeset(%{"status" => "ignored"})
      |> Repo.update()
      |> broadcast_change()
    end
  end

  @doc "Deletes a transaction and reverses its balance; a transfer leg deletes both legs."
  def delete_transaction(%User{} = user, %Transaction{} = transaction) do
    with :ok <- ensure_resource_owner(user, transaction),
         :ok <- ensure_counterpart_owner(user, transaction) do
      delete_transaction(transaction)
    end
  end

  # Deleting a transfer leg deletes both legs and reverses both balances, so
  # the actor must be able to access the counterpart's owner too — otherwise a
  # household member could undo someone's personal leg.
  defp ensure_counterpart_owner(_user, %Transaction{counterpart_transaction_id: nil}), do: :ok

  defp ensure_counterpart_owner(user, %Transaction{counterpart_transaction_id: id}) do
    case Repo.get(Transaction, id) do
      nil -> :ok
      counterpart -> ensure_resource_owner(user, counterpart)
    end
  end

  @doc "Deletes a transaction without an access check; a transfer leg deletes both legs."
  def delete_transaction(%Transaction{counterpart_transaction_id: nil} = transaction) do
    transaction |> Repo.delete() |> broadcast_change()
  end

  def delete_transaction(%Transaction{} = transaction) do
    counterpart = Repo.get(Transaction, transaction.counterpart_transaction_id)

    Repo.transaction(fn ->
      for leg <- [transaction, counterpart], leg do
        reverse_transfer_leg_balance(leg)
        Repo.delete!(leg)
      end

      transaction
    end)
    |> case do
      # notify both legs' owners (a transfer can span personal and household)
      {:ok, _} = ok ->
        broadcast_change({:ok, {transaction, counterpart}})
        ok

      error ->
        error
    end
  end

  defp reverse_transfer_leg_balance(%Transaction{account_id: nil}), do: :ok

  defp reverse_transfer_leg_balance(%Transaction{} = leg) do
    if account = Repo.get(Account, leg.account_id) do
      delta = if leg.type == "expense", do: leg.amount, else: Decimal.negate(leg.amount)

      account
      |> Ecto.Changeset.change(current_balance: Decimal.add(account.current_balance, delta))
      |> Repo.update!()
    end

    :ok
  end

  @doc "Creates an API token for the email ingestion service."
  def create_ingestion_token(%User{} = user) do
    %IngestionToken{user_id: user.id, token: generate_ingestion_token()}
    |> IngestionToken.changeset(%{})
    |> Repo.insert()
  end

  @doc "Revokes one of the user's ingestion tokens."
  def revoke_ingestion_token(%User{} = user, token_id) do
    with %IngestionToken{} = token <- Repo.get(IngestionToken, token_id),
         :ok <- ensure_resource_owner(user, token) do
      token
      |> IngestionToken.changeset(%{"revoked_at" => DateTime.utc_now()})
      |> Repo.update()
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  The user for an active ingestion token: `{:ok, user}` or `{:error, :not_found}`.
  This is the service API's auth check.
  """
  def user_for_ingestion_token(token) when is_binary(token) do
    query = from(t in IngestionToken, where: t.token == ^token and is_nil(t.revoked_at))

    case Repo.one(query) |> Repo.preload(:user) do
      %IngestionToken{user: user} -> {:ok, user}
      nil -> {:error, :not_found}
    end
  end

  defp generate_ingestion_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  @doc """
  Moves money between two accounts (same currency, any of the actor's scopes)
  as a linked expense/income pair, updating both balances atomically. Transfers
  never count as income or spending.

      Finance.create_account_transfer(user, user, %{"from_account_id" => a, "to_account_id" => b, "amount" => "50"})
  """
  def create_account_transfer(%User{} = actor, owner, attrs) do
    with :ok <- ensure_scope_access(actor, owner),
         {:ok, from_account} <-
           fetch_transfer_account(attrs, "from_account_id", :from_account_id, actor),
         {:ok, to_account} <-
           fetch_transfer_account(attrs, "to_account_id", :to_account_id, actor),
         :ok <- ensure_transfer_accounts_differ(from_account, to_account),
         :ok <- ensure_transfer_same_currency(from_account, to_account),
         {:ok, amount} <- parse_transfer_amount(attrs),
         {:ok, transfer_date} <- parse_transfer_date(attrs) do
      notes = presence(Map.get(attrs, "notes") || Map.get(attrs, :notes))

      base = %{
        "amount" => amount,
        "status" => "confirmed",
        "source" => "manual",
        "payment_method" => "bank_transfer",
        "transaction_date" => transfer_date,
        "notes" => notes
      }

      Repo.transaction(fn ->
        out_leg =
          insert_transfer_leg!(
            Map.merge(base, %{
              "type" => "expense",
              "description" => "Transfer to #{to_account.name}",
              "account_id" => from_account.id
            }),
            resource_owner(from_account)
          )

        in_leg =
          insert_transfer_leg!(
            Map.merge(base, %{
              "type" => "income",
              "description" => "Transfer from #{from_account.name}",
              "account_id" => to_account.id
            }),
            resource_owner(to_account)
          )

        out_leg = link_transfer_counterpart!(out_leg, in_leg)
        in_leg = link_transfer_counterpart!(in_leg, out_leg)

        shift_account_balance!(from_account, Decimal.negate(amount))
        shift_account_balance!(to_account, amount)

        {out_leg, in_leg}
      end)
      |> broadcast_change()
    end
  end

  # Any active account the actor can access (personal or a household they
  # belong to); anything else reads as an invalid scope.
  defp fetch_transfer_account(attrs, key, atom_key, %User{} = actor) do
    case presence(Map.get(attrs, key) || Map.get(attrs, atom_key)) do
      nil ->
        {:error, :missing_transfer_account}

      account_id ->
        with %Account{status: "active"} = account <- Repo.get(Account, account_id),
             :ok <- ensure_resource_owner(actor, account) do
          {:ok, account}
        else
          _ -> {:error, :invalid_account_scope}
        end
    end
  end

  defp ensure_transfer_accounts_differ(%Account{id: id}, %Account{id: id}),
    do: {:error, :same_account}

  defp ensure_transfer_accounts_differ(_from, _to), do: :ok

  defp ensure_transfer_same_currency(%Account{currency: currency}, %Account{currency: currency}),
    do: :ok

  defp ensure_transfer_same_currency(_from, _to), do: {:error, :currency_mismatch}

  defp parse_transfer_amount(attrs) do
    raw = Map.get(attrs, "amount") || Map.get(attrs, :amount)

    case Decimal.cast(raw) do
      {:ok, amount} ->
        if Decimal.compare(amount, Decimal.new("0")) == :gt,
          do: {:ok, amount},
          else: {:error, :invalid_transfer_amount}

      _ ->
        {:error, :invalid_transfer_amount}
    end
  end

  defp parse_transfer_date(attrs) do
    case presence(Map.get(attrs, "transaction_date") || Map.get(attrs, :transaction_date)) do
      nil ->
        {:ok, Date.utc_today()}

      %Date{} = date ->
        {:ok, date}

      value when is_binary(value) ->
        case Date.from_iso8601(value) do
          {:ok, date} -> {:ok, date}
          _ -> {:error, :invalid_transfer_date}
        end
    end
  end

  defp presence(nil), do: nil
  defp presence(""), do: nil
  defp presence(value), do: value

  defp trimmed_presence(value) when is_binary(value), do: value |> String.trim() |> presence()
  defp trimmed_presence(value), do: presence(value)

  defp insert_transfer_leg!(attrs, owner) do
    %Transaction{}
    |> Transaction.changeset(scope_attrs(attrs, owner))
    |> Repo.insert!()
  end

  defp link_transfer_counterpart!(%Transaction{} = leg, %Transaction{id: counterpart_id}) do
    leg
    |> Ecto.Changeset.change(counterpart_transaction_id: counterpart_id)
    |> Repo.update!()
  end

  defp shift_account_balance!(%Account{} = account, delta) do
    account
    |> Ecto.Changeset.change(current_balance: Decimal.add(account.current_balance, delta))
    |> Repo.update!()
  end

  @doc "Confirmed income between two dates (single currency, legacy)."
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
    |> where([t], is_nil(t.counterpart_transaction_id))
    |> where([t], t.transaction_date >= ^start_date and t.transaction_date <= ^end_date)
    |> select([t], sum(t.amount))
    |> Repo.one() || Decimal.new(0)
  end

  @doc "Confirmed expenses between two dates (single currency, legacy)."
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
    |> where([t], is_nil(t.counterpart_transaction_id))
    |> where([t], t.transaction_date >= ^start_date and t.transaction_date <= ^end_date)
    |> select([t], sum(t.amount))
    |> Repo.one() || Decimal.new(0)
  end

  @doc "Income, expenses and balance between two dates (single currency, legacy)."
  def get_financial_summary(%User{} = user, start_date, end_date) do
    get_financial_summary_for_scope(user, start_date, end_date)
  end

  def get_financial_summary(owner, start_date, end_date) do
    get_financial_summary_for_scope(owner, start_date, end_date)
  end

  @doc """
  Income, expenses and balance per currency between two dates, transfers
  excluded. Options: `:statuses` (default confirmed),
  `:exclude_debt_payment_expenses`.
  """
  def get_currency_summary(owner, start_date, end_date, opts \\ []) do
    statuses = Keyword.get(opts, :statuses, ["confirmed"])
    exclude_debt_payment_expenses = Keyword.get(opts, :exclude_debt_payment_expenses, false)

    rows =
      Transaction
      |> scope_query(owner)
      |> join(:left, [transaction], account in assoc(transaction, :account))
      |> where([transaction, _account], transaction.status in ^statuses)
      |> where([transaction, _account], is_nil(transaction.counterpart_transaction_id))
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

  @doc """
  Active accounts in a scope. `{:ok, list}`. Scoped: `{:error, :forbidden}` unless
  `actor` can access `owner`.
  """
  def list_accounts(%User{} = actor, owner) do
    with :ok <- ensure_scope_access(actor, owner) do
      {:ok, do_list_accounts(owner)}
    end
  end

  @doc "The user's active personal accounts."
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

  @doc "An account in a scope; raises if missing."
  def get_account!(%User{} = actor, owner, id) do
    with :ok <- ensure_scope_access(actor, owner) do
      Account
      |> scope_query(owner)
      |> Repo.get!(id)
    end
  end

  @doc "Creates a personal account. See `create_account/3`."
  def create_account(%User{} = user, attrs \\ %{}) do
    create_account(user, user, attrs)
  end

  @doc """
  Creates an account in a scope with its starting balance. Scoped:
  `{:error, :forbidden}` unless `actor` can access `owner`.
  """
  def create_account(%User{} = actor, owner, attrs) do
    with :ok <- ensure_scope_access(actor, owner),
         attrs <- scope_attrs(attrs, owner) do
      %Account{}
      |> Account.changeset(attrs)
      |> Repo.insert()
      |> broadcast_change()
    end
  end

  @doc """
  Creates a household and, if any starting-account field is filled, its first
  account, in one transaction. `{:ok, household}` or
  `{:error, :household | :account, changeset}`.
  """
  def create_household_with_account(%User{} = user, household_attrs, account_attrs \\ %{}) do
    account_attrs = starting_account_attrs(account_attrs)

    Repo.transaction(fn ->
      household =
        case Accounts.create_household(user, household_attrs) do
          {:ok, household} -> household
          {:error, changeset} -> Repo.rollback({:household, changeset})
        end

      if account_attrs do
        case create_account(user, household, account_attrs) do
          {:ok, _account} -> :ok
          {:error, changeset} -> Repo.rollback({:account, changeset})
        end
      end

      household
    end)
    |> case do
      {:ok, household} ->
        # The creator's other tabs (and the hub) pick up the new household.
        notify_user_change(user.id)

        {:ok, household}

      {:error, {step, changeset}} ->
        {:error, step, changeset}
    end
  end

  @starting_account_fields ["name", "kind", "currency", "current_balance"]

  defp starting_account_attrs(attrs) do
    attrs = attrs |> Map.new() |> Map.new(fn {key, value} -> {to_string(key), value} end)

    name = trimmed_presence(attrs["name"])
    balance = trimmed_presence(attrs["current_balance"])

    if name || balance do
      attrs
      |> Map.take(@starting_account_fields)
      |> Map.put("name", name || "Household account")
      |> Map.put("current_balance", balance || "0")
      |> Map.put_new("kind", "checking")
      |> Map.put_new("currency", @default_currency)
    end
  end

  @doc "Edits an account; the currency is locked once it has transactions."
  def update_account(%User{} = user, %Account{} = account, attrs) do
    with :ok <- ensure_resource_owner(user, account) do
      account
      |> Account.changeset(
        Map.drop(Map.new(attrs), [
          "status",
          :status,
          "user_id",
          :user_id,
          "household_id",
          :household_id
        ])
      )
      |> lock_currency_with_history(account)
      |> Repo.update()
      |> broadcast_change()
    end
  end

  @doc "Hides an account from lists and pickers; history stays."
  def archive_account(%User{} = user, %Account{} = account),
    do: set_account_status(user, account, "archived")

  @doc "Brings an archived account back."
  def restore_account(%User{} = user, %Account{} = account),
    do: set_account_status(user, account, "active")

  @doc """
  Deletes an account with no transactions; otherwise `{:error, :has_transactions}`
  (archive it).
  """
  def delete_account(%User{} = user, %Account{} = account) do
    with :ok <- ensure_resource_owner(user, account) do
      if account_has_transactions?(account) do
        {:error, :has_transactions}
      else
        account |> Repo.delete() |> broadcast_change()
      end
    end
  end

  @doc "Which of the given account ids have at least one transaction (a `MapSet`)."
  def account_ids_with_transactions([]), do: MapSet.new()

  def account_ids_with_transactions(account_ids) do
    Transaction
    |> where([transaction], transaction.account_id in ^account_ids)
    |> distinct(true)
    |> select([transaction], transaction.account_id)
    |> Repo.all()
    |> MapSet.new()
  end

  @doc "A debt payment in a scope; raises if missing."
  def get_debt_payment!(%User{} = actor, owner, id) do
    with :ok <- ensure_scope_access(actor, owner) do
      DebtPayment |> scope_query(owner) |> Repo.get!(id)
    end
  end

  @doc "Whether any transaction uses this account."
  def account_has_transactions?(%Account{id: id}) do
    Transaction |> where([transaction], transaction.account_id == ^id) |> Repo.exists?()
  end

  @doc "Archived accounts in a scope. `{:ok, list}`."
  def list_archived_accounts(%User{} = actor, owner) do
    with :ok <- ensure_scope_access(actor, owner) do
      {:ok,
       Account
       |> scope_query(owner)
       |> where([account], account.status == "archived")
       |> order_by([account], asc: account.name)
       |> Repo.all()}
    end
  end

  defp set_account_status(user, account, status) do
    with :ok <- ensure_resource_owner(user, account) do
      account
      |> Ecto.Changeset.change(status: status)
      |> Repo.update()
      |> broadcast_change()
    end
  end

  defp lock_currency_with_history(changeset, account) do
    if Ecto.Changeset.get_change(changeset, :currency) && account_has_transactions?(account) do
      Ecto.Changeset.add_error(
        changeset,
        :currency,
        "can't change once the account has transactions"
      )
    else
      changeset
    end
  end

  @doc "An account changeset for forms."
  def change_account(%Account{} = account \\ %Account{}) do
    Account.changeset(account, %{})
  end

  @doc """
  Each active account with its income, expenses, net and transaction count for a
  date range. `{:ok, list}`.
  """
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

  @doc "The user's personal categories, optionally of one `type`."
  def list_categories_for_user(%User{} = user, type \\ nil) do
    do_list_categories(user, type)
  end

  @doc "Like `list_categories_for_user/2`, by user id."
  def list_user_categories(user_id, type \\ nil) do
    do_list_categories(%User{id: user_id}, type)
  end

  @doc "Categories in a scope, optionally of one `type`. `{:ok, list}`."
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

  @doc "A category by id, or nil (despite the name). No scope check."
  def get_category!(id), do: Repo.get(Category, id)

  @doc "One of the user's personal categories; raises if missing."
  def get_category_for_user!(%User{} = user, id) do
    Category
    |> where([category], category.user_id == ^user.id)
    |> Repo.get!(id)
  end

  @doc "A category in a scope; raises if missing."
  def get_category!(%User{} = actor, owner, id) do
    with :ok <- ensure_scope_access(actor, owner) do
      Category
      |> scope_query(owner)
      |> Repo.get!(id)
    end
  end

  @doc "Creates a personal category. See `create_category/3`."
  def create_category(%User{} = user, attrs \\ %{}) do
    create_category(user, user, attrs)
  end

  @doc """
  Creates a category in a scope. Scoped: `{:error, :forbidden}` unless `actor` can
  access `owner`.
  """
  def create_category(%User{} = actor, owner, attrs) do
    with :ok <- ensure_scope_access(actor, owner),
         attrs <- scope_attrs(attrs, owner) do
      %Category{}
      |> Category.changeset(attrs)
      |> Repo.insert()
      |> broadcast_change()
    end
  end

  @doc "A category changeset for forms."
  def change_category(%Category{} = category \\ %Category{}) do
    Category.changeset(category, %{})
  end

  @doc "Edits a category (name, type, colour, icon)."
  def update_category(%User{} = user, %Category{} = category, attrs) do
    with :ok <- ensure_resource_owner(user, category) do
      update_category(category, attrs)
    end
  end

  @doc "Edits a category without an access check."
  def update_category(%Category{} = category, attrs) do
    category
    |> Category.changeset(attrs)
    |> Repo.update()
    |> broadcast_change()
  end

  @doc "Deletes a category; its transactions stay, uncategorised."
  def delete_category(%User{} = user, %Category{} = category) do
    with :ok <- ensure_resource_owner(user, category) do
      delete_category(category)
    end
  end

  @doc "Deletes a category without an access check."
  def delete_category(%Category{} = category) do
    category |> Repo.delete() |> broadcast_change()
  end

  # ------ Budgets ------

  @doc "The user's personal budgets."
  def list_budgets_for_user(%User{} = user) do
    do_list_budgets(user)
  end

  @doc "Like `list_budgets_for_user/1`, by user id."
  def list_user_budgets(user_id) do
    do_list_budgets(%User{id: user_id})
  end

  @doc "Budgets in a scope. `{:ok, list}`."
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

  @doc "A budget by id with user and category; raises if missing. No scope check."
  def get_budget!(id) do
    Budget
    |> preload([:user, :category])
    |> Repo.get!(id)
  end

  @doc "One of the user's personal budgets; raises if missing."
  def get_budget_for_user!(%User{} = user, id) do
    Budget
    |> where([budget], budget.user_id == ^user.id)
    |> preload([:user, :category])
    |> Repo.get!(id)
  end

  @doc "A budget in a scope; raises if missing."
  def get_budget!(%User{} = actor, owner, id) do
    with :ok <- ensure_scope_access(actor, owner) do
      Budget
      |> scope_query(owner)
      |> preload([:user, :household, :category])
      |> Repo.get!(id)
    end
  end

  @doc "Creates a personal budget. See `create_budget/3`."
  def create_budget(%User{} = user, attrs \\ %{}) do
    create_budget(user, user, attrs)
  end

  @doc """
  Creates a budget in a scope. Scoped: `{:error, :forbidden}` unless `actor` can
  access `owner`.
  """
  def create_budget(%User{} = actor, owner, attrs) do
    with :ok <- ensure_scope_access(actor, owner),
         attrs <- scope_attrs(attrs, owner),
         :ok <- ensure_category_in_scope(attrs, owner) do
      %Budget{}
      |> Budget.changeset(attrs)
      |> Repo.insert()
      |> broadcast_change()
    end
  end

  @doc "A budget changeset for forms."
  def change_budget(%Budget{} = budget \\ %Budget{}) do
    Budget.changeset(budget, %{})
  end

  @doc "`check_budget_status/1` for each personal budget."
  def list_budget_statuses_for_user(%User{} = user) do
    user
    |> list_budgets_for_user()
    |> Enum.map(&check_budget_status/1)
  end

  @doc "`check_budget_status/1` for each budget in a scope. `{:ok, list}`."
  def list_budget_statuses(%User{} = actor, owner) do
    with {:ok, budgets} <- list_budgets(actor, owner) do
      {:ok, Enum.map(budgets, &check_budget_status/1)}
    end
  end

  @doc "Edits a budget; its category must belong to the same scope."
  def update_budget(%User{} = user, %Budget{} = budget, attrs) do
    with :ok <- ensure_resource_owner(user, budget) do
      with :ok <- ensure_category_in_scope(attrs, resource_owner(budget)) do
        update_budget(budget, attrs)
      end
    end
  end

  @doc "Edits a budget without an access check."
  def update_budget(%Budget{} = budget, attrs) do
    budget
    |> Budget.changeset(attrs)
    |> Repo.update()
    |> broadcast_change()
  end

  @doc "Deletes a budget."
  def delete_budget(%User{} = user, %Budget{} = budget) do
    with :ok <- ensure_resource_owner(user, budget) do
      delete_budget(budget)
    end
  end

  @doc "Deletes a budget without an access check."
  def delete_budget(%Budget{} = budget), do: budget |> Repo.delete() |> broadcast_change()

  # ------ Debts ------

  @doc "The user's personal debts."
  def list_debts_for_user(%User{} = user) do
    do_list_debts(user)
  end

  @doc "Debts in a scope. `{:ok, list}`."
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

  @doc "One of the user's personal debts; raises if missing."
  def get_debt_for_user!(%User{} = user, id) do
    Debt
    |> where([debt], debt.user_id == ^user.id)
    |> preload(payments: ^recent_debt_payments_query())
    |> Repo.get!(id)
  end

  @doc "A debt in a scope; raises if missing."
  def get_debt!(%User{} = actor, owner, id) do
    with :ok <- ensure_scope_access(actor, owner) do
      Debt
      |> scope_query(owner)
      |> preload(payments: ^recent_debt_payments_query())
      |> Repo.get!(id)
    end
  end

  @doc "A debt changeset for forms."
  def change_debt(%Debt{} = debt \\ %Debt{}) do
    Debt.changeset(debt, %{})
  end

  @doc "Creates a personal debt. See `create_debt/3`."
  def create_debt(%User{} = user, attrs \\ %{}) do
    create_debt(user, user, attrs)
  end

  @doc """
  Creates a debt in a scope. Scoped: `{:error, :forbidden}` unless `actor` can
  access `owner`.
  """
  def create_debt(%User{} = actor, owner, attrs) do
    with :ok <- ensure_scope_access(actor, owner),
         attrs <- scope_attrs(attrs, owner) do
      %Debt{}
      |> Debt.changeset(attrs)
      |> Repo.insert()
      |> broadcast_change()
    end
  end

  @doc "Edits a debt."
  def update_debt(%User{} = user, %Debt{} = debt, attrs) do
    with :ok <- ensure_resource_owner(user, debt) do
      debt
      |> Debt.changeset(attrs)
      |> Repo.update()
      |> broadcast_change()
    end
  end

  @doc "Deletes a debt."
  def delete_debt(%User{} = user, %Debt{} = debt) do
    with :ok <- ensure_resource_owner(user, debt) do
      debt
      |> Debt.changeset(%{"status" => "archived"})
      |> Repo.update()
      |> broadcast_change()
    end
  end

  @doc "A debt payment changeset for forms."
  def change_debt_payment(%DebtPayment{} = payment \\ %DebtPayment{}) do
    DebtPayment.changeset(payment, %{})
  end

  @doc "The user's latest debt payments (`:limit`, default 25)."
  def list_debt_payments_for_user(%User{} = user, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)

    DebtPayment
    |> where([payment], payment.user_id == ^user.id)
    |> order_by([payment], desc: payment.payment_date, desc: payment.inserted_at)
    |> limit(^limit)
    |> preload([:debt, :transaction])
    |> Repo.all()
  end

  @doc "Payments recorded against one debt."
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

  @doc """
  Records a payment that lowers the debt (paid off at zero) and, when asked, logs it
  as an expense, atomically.
  """
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
        |> broadcast_change()
      else
        {:error, changeset}
      end
    end
  end

  @doc "Undoes a payment: restores the balance, reopens a paid-off debt, deletes its expense."
  def delete_debt_payment(%User{} = user, %DebtPayment{} = payment) do
    with :ok <- ensure_resource_owner(user, payment) do
      Repo.transaction(fn ->
        if payment.transaction_id do
          case Repo.get(Transaction, payment.transaction_id) do
            nil -> :ok
            transaction -> Repo.delete!(transaction)
          end
        end

        restore_debt_after_payment_removal!(payment)
        Repo.delete!(payment)
      end)
      |> broadcast_change()
    end
  end

  defp restore_debt_after_payment_removal!(%DebtPayment{debt_id: debt_id, amount: amount}) do
    debt = Repo.get!(Debt, debt_id)
    balance = Decimal.add(debt.current_balance, amount)
    status = if debt.status == "paid_off", do: "active", else: debt.status

    debt
    |> Debt.changeset(%{"current_balance" => balance, "status" => status})
    |> Repo.update!()
  end

  @doc "The user's saved payoff plans."
  def list_payoff_plans_for_user(%User{} = user) do
    do_list_payoff_plans(user)
  end

  @doc "Saved payoff plans in a scope. `{:ok, list}`."
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

  @doc """
  Snowball vs avalanche plans for the scope's debts, paying `:monthly_amount`
  (default: this month's free cash flow). Not saved.
  """
  def generate_debt_payoff_comparison(%User{} = user, opts \\ []) do
    today = Keyword.get(opts, :today, Date.utc_today())
    starts_on = Keyword.get(opts, :starts_on, Date.beginning_of_month(today))
    health = get_financial_health(user, today: today)
    monthly_amount = Keyword.get(opts, :monthly_amount, health.current_month.free_cash_flow)

    user
    |> list_debts_for_user()
    |> DebtPlanner.compare(monthly_amount, starts_on)
  end

  @doc """
  Scope version of `generate_debt_payoff_comparison/2`. `{:error, :forbidden}` if no
  access.
  """
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

  @doc "Saves a personal payoff plan. See `save_debt_payoff_plan/3`."
  def save_debt_payoff_plan(%User{} = user, attrs) do
    save_debt_payoff_plan(user, user, attrs)
  end

  @doc """
  Saves a payoff plan in a scope. Scoped: `{:error, :forbidden}` unless `actor` can
  access `owner`.
  """
  def save_debt_payoff_plan(%User{} = actor, owner, attrs) do
    with :ok <- ensure_scope_access(actor, owner),
         attrs <- scope_attrs(attrs, owner) do
      %DebtPayoffPlan{}
      |> DebtPayoffPlan.changeset(attrs)
      |> Repo.insert()
    end
  end

  @doc "Saves one plan from `generate_debt_payoff_comparison/2` as a named plan."
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

  @doc "Scope version of `save_generated_debt_payoff_plan/2`."
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

  # ------ Savings goals ------

  @doc "The user's personal savings goals."
  def list_savings_goals_for_user(%User{} = user) do
    do_list_savings_goals(user)
  end

  @doc "Savings goals in a scope. `{:ok, list}`."
  def list_savings_goals(%User{} = actor, owner) do
    with :ok <- ensure_scope_access(actor, owner) do
      {:ok, do_list_savings_goals(owner)}
    end
  end

  defp do_list_savings_goals(owner) do
    SavingsGoal
    |> scope_query(owner)
    |> where([goal], goal.status in ["active", "achieved"])
    |> order_by([goal], asc_nulls_last: goal.target_date, asc: goal.name)
    |> Repo.all()
  end

  @doc "A savings goal in a scope; raises if missing."
  def get_savings_goal!(%User{} = actor, owner, id) do
    with :ok <- ensure_scope_access(actor, owner) do
      SavingsGoal
      |> scope_query(owner)
      |> Repo.get!(id)
    end
  end

  @doc "A savings goal changeset for forms."
  def change_savings_goal(%SavingsGoal{} = goal \\ %SavingsGoal{}) do
    SavingsGoal.changeset(goal, %{})
  end

  @doc "Creates a personal savings goal. See `create_savings_goal/3`."
  def create_savings_goal(%User{} = user, attrs \\ %{}) do
    create_savings_goal(user, user, attrs)
  end

  @doc """
  Creates a savings goal in a scope. Scoped: `{:error, :forbidden}` unless `actor`
  can access `owner`.
  """
  def create_savings_goal(%User{} = actor, owner, attrs) do
    with :ok <- ensure_scope_access(actor, owner),
         attrs <- scope_attrs(attrs, owner) do
      %SavingsGoal{}
      |> SavingsGoal.changeset(attrs)
      |> Repo.insert()
      |> broadcast_change()
    end
  end

  @doc "Edits a savings goal."
  def update_savings_goal(%User{} = user, %SavingsGoal{} = goal, attrs) do
    with :ok <- ensure_resource_owner(user, goal) do
      goal
      |> SavingsGoal.changeset(attrs)
      |> Repo.update()
      |> broadcast_change()
    end
  end

  @doc "Adds `amount` to a goal's saved amount."
  def contribute_to_savings_goal(%User{} = user, %SavingsGoal{} = goal, amount) do
    with :ok <- ensure_resource_owner(user, goal) do
      new_saved_amount = Decimal.add(goal.saved_amount || Decimal.new("0"), amount)

      status =
        if Decimal.compare(new_saved_amount, goal.target_amount) != :lt,
          do: "achieved",
          else: goal.status

      goal
      |> SavingsGoal.changeset(%{"saved_amount" => new_saved_amount, "status" => status})
      |> Repo.update()
      |> broadcast_change()
    end
  end

  @doc "Deletes a savings goal."
  def delete_savings_goal(%User{} = user, %SavingsGoal{} = goal) do
    with :ok <- ensure_resource_owner(user, goal) do
      goal
      |> SavingsGoal.changeset(%{"status" => "archived"})
      |> Repo.update()
      |> broadcast_change()
    end
  end

  @doc """
  Health snapshot (debt-to-income, payment burden, cash flow, warnings); see
  `Finance.Health`.
  """
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

  @doc "Scope version of `get_financial_health/2`."
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
  Spending against a budget for its period: `%{budget, spent, remaining,
  percentage, is_over, is_near_limit}`.
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
    from(payment in DebtPayment,
      order_by: [desc: payment.payment_date, desc: payment.inserted_at],
      limit: 3,
      preload: [:transaction]
    )
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

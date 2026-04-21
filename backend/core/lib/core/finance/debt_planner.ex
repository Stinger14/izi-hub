defmodule Core.Finance.DebtPlanner do
  @moduledoc """
  Builds deterministic debt payoff projections from debt snapshots.
  """

  @max_months 600
  @strategies [:snowball, :avalanche]

  def compare(debts, monthly_amount, starts_on) do
    Enum.map(@strategies, &build_plan(&1, debts, monthly_amount, starts_on))
  end

  def build_plan(strategy, debts, monthly_amount, starts_on) when strategy in @strategies do
    debts = Enum.map(debts, &debt_state/1)
    monthly_amount = decimal(monthly_amount)
    minimum_total = sum_decimal(debts, & &1.minimum_payment)
    feasible? = Decimal.compare(monthly_amount, minimum_total) != :lt

    schedule =
      if feasible?, do: project_schedule(strategy, debts, monthly_amount, starts_on), else: []

    payoff_months = length(schedule)
    target_payoff_date = if payoff_months > 0, do: Date.add(starts_on, payoff_months * 30)

    %{
      strategy: Atom.to_string(strategy),
      monthly_amount: monthly_amount,
      minimum_payment_total: minimum_total,
      extra_payment: max_decimal(Decimal.sub(monthly_amount, minimum_total), Decimal.new("0")),
      feasible?: feasible?,
      debt_count: length(debts),
      starting_balance: sum_decimal(debts, & &1.balance),
      estimated_interest: sum_decimal(schedule, & &1.interest),
      payoff_months: payoff_months,
      target_payoff_date: target_payoff_date,
      schedule: schedule,
      payoff_order: payoff_order(strategy, debts)
    }
  end

  defp project_schedule(strategy, debts, monthly_amount, starts_on) do
    do_project(strategy, debts, monthly_amount, starts_on, 1, [])
  end

  defp do_project(_strategy, _debts, _monthly_amount, _starts_on, _month, schedule)
       when length(schedule) >= @max_months do
    Enum.reverse(schedule)
  end

  defp do_project(strategy, debts, monthly_amount, starts_on, month, schedule) do
    active_debts = Enum.reject(debts, &zero?(&1.balance))

    if active_debts == [] do
      Enum.reverse(schedule)
    else
      interest_by_id = Map.new(active_debts, &{&1.id, monthly_interest(&1)})

      debts_with_interest =
        Enum.map(debts, fn debt ->
          interest = Map.get(interest_by_id, debt.id, Decimal.new("0"))
          %{debt | balance: Decimal.add(debt.balance, interest)}
        end)

      {updated_debts, payments} = apply_payments(strategy, debts_with_interest, monthly_amount)

      entry = %{
        month: month,
        date: Date.add(starts_on, (month - 1) * 30),
        interest: sum_decimal(Map.values(interest_by_id)),
        payment: sum_decimal(Map.values(payments)),
        remaining_balance: sum_decimal(updated_debts, & &1.balance)
      }

      do_project(strategy, updated_debts, monthly_amount, starts_on, month + 1, [entry | schedule])
    end
  end

  defp apply_payments(strategy, debts, monthly_amount) do
    active_debts = Enum.reject(debts, &zero?(&1.balance))
    minimum_total = sum_decimal(active_debts, &min_decimal(&1.minimum_payment, &1.balance))
    extra = max_decimal(Decimal.sub(monthly_amount, minimum_total), Decimal.new("0"))
    focus_debt = strategy |> payoff_order(active_debts) |> List.first()

    Enum.map_reduce(debts, %{}, fn debt, payments ->
      minimum =
        if zero?(debt.balance),
          do: Decimal.new("0"),
          else: min_decimal(debt.minimum_payment, debt.balance)

      extra_payment = if focus_debt && debt.id == focus_debt.id, do: extra, else: Decimal.new("0")
      payment = min_decimal(Decimal.add(minimum, extra_payment), debt.balance)

      {%{debt | balance: Decimal.sub(debt.balance, payment)}, Map.put(payments, debt.id, payment)}
    end)
  end

  defp payoff_order(:snowball, debts) do
    Enum.sort(debts, fn left, right ->
      case Decimal.compare(left.balance, right.balance) do
        :lt -> true
        :gt -> false
        :eq -> left.name <= right.name
      end
    end)
  end

  defp payoff_order(:avalanche, debts) do
    Enum.sort(debts, fn left, right ->
      case Decimal.compare(left.apr, right.apr) do
        :gt -> true
        :lt -> false
        :eq -> Decimal.compare(left.balance, right.balance) != :gt
      end
    end)
  end

  defp payoff_order(strategy, debts) when is_atom(strategy),
    do: payoff_order(strategy, Enum.reject(debts, &zero?(&1.balance)))

  defp debt_state(debt) do
    %{
      id: debt.id,
      name: debt.name,
      balance: decimal(debt.current_balance),
      apr: decimal(debt.apr || Decimal.new("0")),
      minimum_payment: decimal(debt.minimum_payment)
    }
  end

  defp monthly_interest(debt) do
    debt.balance
    |> Decimal.mult(debt.apr)
    |> Decimal.div(Decimal.new("100"))
    |> Decimal.div(Decimal.new("12"))
  end

  defp decimal(%Decimal{} = value), do: value
  defp decimal(nil), do: Decimal.new("0")
  defp decimal(value), do: Decimal.new(to_string(value))

  defp sum_decimal(values), do: Enum.reduce(values, Decimal.new("0"), &Decimal.add/2)
  defp sum_decimal(values, mapper), do: values |> Enum.map(mapper) |> sum_decimal()

  defp zero?(value), do: Decimal.compare(value, Decimal.new("0")) != :gt

  defp min_decimal(left, right),
    do: if(Decimal.compare(left, right) == :gt, do: right, else: left)

  defp max_decimal(left, right),
    do: if(Decimal.compare(left, right) == :lt, do: right, else: left)
end

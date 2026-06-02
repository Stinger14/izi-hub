defmodule Core.Finance.Health do
  @moduledoc """
  Calculates month-oriented financial health signals.
  """

  def build(current_month, next_month, debts) do
    minimum_debt_payment = sum_decimal(debts, & &1.minimum_payment)
    current_free_cash_flow = Decimal.sub(current_month.income, current_month.expenses)
    next_free_cash_flow = Decimal.sub(next_month.income, next_month.expenses)
    total_debt = sum_decimal(debts, & &1.current_balance)

    %{
      current_month: Map.put(current_month, :free_cash_flow, current_free_cash_flow),
      next_month: Map.put(next_month, :free_cash_flow, next_free_cash_flow),
      total_debt: total_debt,
      minimum_debt_payment: minimum_debt_payment,
      debt_to_income_ratio: ratio(total_debt, current_month.income),
      minimum_payment_burden: ratio(minimum_debt_payment, current_month.income),
      warnings:
        warnings(debts, current_month.income, current_free_cash_flow, minimum_debt_payment)
    }
  end

  defp warnings(debts, income, free_cash_flow, minimum_debt_payment) do
    []
    |> maybe_add(
      Decimal.compare(income, Decimal.new("0")) != :gt,
      "No current-month income has been recorded."
    )
    |> maybe_add(
      Decimal.compare(free_cash_flow, Decimal.new("0")) == :lt,
      "Current-month cash flow is negative."
    )
    |> maybe_add(
      Decimal.compare(free_cash_flow, minimum_debt_payment) == :lt,
      "Free cash flow is below total minimum debt payments."
    )
    |> maybe_add(
      Enum.any?(debts, &is_nil(&1.apr)),
      "One or more debts are missing APR, so projections may be understated."
    )
    |> Enum.reverse()
  end

  defp maybe_add(warnings, true, warning), do: [warning | warnings]
  defp maybe_add(warnings, false, _warning), do: warnings

  defp ratio(_numerator, denominator) when is_nil(denominator), do: 0.0

  defp ratio(numerator, denominator) do
    if Decimal.compare(denominator, Decimal.new("0")) == :gt do
      numerator
      |> Decimal.div(denominator)
      |> Decimal.mult(Decimal.new("100"))
      |> Decimal.round(1)
      |> Decimal.to_float()
    else
      0.0
    end
  end

  defp sum_decimal(values, mapper),
    do: values |> Enum.map(mapper) |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)
end

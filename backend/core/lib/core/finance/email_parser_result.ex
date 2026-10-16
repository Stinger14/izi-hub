defmodule Core.Finance.EmailParserResult do
  @moduledoc """
  What a parser found in an email: amount, type, date, merchant, currency.

  Context: returned by parsers such as `BankAlertParser`; `EmailIngestion`
  turns it into a pending transaction.
  """

  @enforce_keys [:external_id, :amount, :type, :transaction_date]
  defstruct [
    :external_id,
    :amount,
    :type,
    :transaction_date,
    :merchant,
    :currency,
    :description,
    :raw_description,
    :review_reason,
    :confidence,
    :source
  ]
end

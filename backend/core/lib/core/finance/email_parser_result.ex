defmodule Core.Finance.EmailParserResult do
  @moduledoc """
  Parsed transaction candidate extracted from an email message.
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

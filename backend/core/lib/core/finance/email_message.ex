defmodule Core.Finance.EmailMessage do
  @moduledoc """
  Normalized email payload used by finance ingestion parsers.
  """

  @enforce_keys [:message_id, :from, :subject]
  defstruct [
    :provider,
    :message_id,
    :from,
    :subject,
    :received_at,
    :text_body,
    :html_body
  ]
end

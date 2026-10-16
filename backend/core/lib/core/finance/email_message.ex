defmodule Core.Finance.EmailMessage do
  @moduledoc """
  A normalised email (from, subject, body, received date) handed to parsers.

  Context: built by `EmailIngestion` from the API payload.
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

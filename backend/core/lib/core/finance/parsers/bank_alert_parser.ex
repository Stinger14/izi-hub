defmodule Core.Finance.Parsers.BankAlertParser do
  @moduledoc """
  Extracts transaction candidates from a narrow bank alert email format.
  """

  alias Core.Finance.{EmailMessage, EmailParserResult}

  @supported_senders [
    "alerts@bank.com",
    "alerts@bank.example",
    "notifications@bank.com"
  ]

  @expense_keywords ["purchase", "debit", "withdrawal", "card purchase"]
  @income_keywords ["deposit", "payment received", "credit", "transfer received"]

  def parse(%EmailMessage{} = message) do
    with true <- supported_sender?(message.from),
         body when is_binary(body) <- email_body(message),
         {:ok, amount} <- parse_amount(body),
         {:ok, type} <- parse_type(message, body),
         {:ok, transaction_date} <- parse_transaction_date(message),
         {:ok, merchant} <- parse_merchant(body) do
      {:ok,
       %EmailParserResult{
         external_id: message.message_id,
         amount: amount,
         type: type,
         transaction_date: transaction_date,
         merchant: merchant,
         description: build_description(type, merchant, message.subject),
         raw_description: truncate(body, 1000),
         review_reason: "Parsed from bank email",
         confidence: confidence(message.subject, merchant),
         source: "email"
       }}
    else
      false -> :no_match
      :error -> {:error, :unparseable_email}
      {:error, _reason} = error -> error
      nil -> {:error, :unparseable_email}
    end
  end

  defp supported_sender?(from) when is_binary(from) do
    normalized = String.trim(String.downcase(from))
    Enum.any?(@supported_senders, &String.contains?(normalized, &1))
  end

  defp supported_sender?(_from), do: false

  defp email_body(%EmailMessage{text_body: text_body, html_body: html_body}) do
    text_body || html_body
  end

  defp parse_amount(body) do
    case Regex.run(~r/(?:USD|US\$|\$)\s*([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{2})?)/i, body) do
      [_, amount] ->
        normalized = String.replace(amount, ",", "")
        {:ok, Decimal.new(normalized)}

      _ ->
        {:error, :amount_not_found}
    end
  end

  defp parse_type(%EmailMessage{subject: subject}, body) do
    haystack = String.downcase("#{subject} #{body}")

    cond do
      Enum.any?(@expense_keywords, &String.contains?(haystack, &1)) -> {:ok, "expense"}
      Enum.any?(@income_keywords, &String.contains?(haystack, &1)) -> {:ok, "income"}
      true -> {:error, :type_not_found}
    end
  end

  defp parse_transaction_date(%EmailMessage{received_at: %DateTime{} = received_at}) do
    {:ok, DateTime.to_date(received_at)}
  end

  defp parse_transaction_date(%EmailMessage{received_at: %NaiveDateTime{} = received_at}) do
    {:ok, NaiveDateTime.to_date(received_at)}
  end

  defp parse_transaction_date(_message), do: {:ok, Date.utc_today()}

  defp parse_merchant(body) do
    patterns = [
      ~r/(?:merchant|vendor):\s*([^\n\r]+)/i,
      ~r/(?:at|from)\s+([A-Za-z0-9 &'.,-]+)/i
    ]

    case Enum.find_value(patterns, &Regex.run(&1, body)) do
      [_, merchant] ->
        {:ok, merchant |> String.trim() |> String.trim_trailing(".") |> truncate(255)}

      _ ->
        {:ok, nil}
    end
  end

  defp build_description(type, nil, subject), do: default_description(type, subject)
  defp build_description(_type, merchant, _subject), do: merchant

  defp default_description("income", subject), do: "Email income: #{truncate(subject, 60)}"
  defp default_description(_type, subject), do: "Email expense: #{truncate(subject, 60)}"

  defp confidence(subject, merchant) do
    haystack = String.downcase(subject || "")

    cond do
      merchant && String.contains?(haystack, "alert") -> 0.95
      merchant -> 0.85
      true -> 0.7
    end
  end

  defp truncate(nil, _limit), do: nil

  defp truncate(value, limit) do
    String.slice(value, 0, limit)
  end
end

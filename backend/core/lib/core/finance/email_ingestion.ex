defmodule Core.Finance.EmailIngestion do
  @moduledoc """
  Converts supported email alerts into pending-review transactions.
  """

  alias Core.Accounts.User
  alias Core.Finance
  alias Core.Finance.{EmailMessage, EmailParserResult}
  alias Core.Finance.Parsers.BankAlertParser

  @parsers [BankAlertParser]

  def ingest(%User{} = user, attrs) when is_map(attrs) do
    message = build_message(attrs)

    case parse_message(message) do
      {:ok, %EmailParserResult{} = result} ->
        case create_candidate(user, result) do
          {:error, :duplicate_external_id} -> {:ok, :duplicate}
          other -> other
        end

      :no_match ->
        {:error, :unsupported_email}

      {:error, _reason} ->
        {:error, :unparseable_email}
    end
  end

  defp build_message(attrs) do
    %EmailMessage{
      provider: map_get(attrs, "provider"),
      message_id: map_get(attrs, "message_id"),
      from: map_get(attrs, "from"),
      subject: map_get(attrs, "subject"),
      received_at: map_get(attrs, "received_at"),
      text_body: map_get(attrs, "text_body"),
      html_body: map_get(attrs, "html_body")
    }
  end

  defp parse_message(message) do
    Enum.reduce_while(@parsers, :no_match, fn parser, _acc ->
      case parser.parse(message) do
        :no_match -> {:cont, :no_match}
        result -> {:halt, result}
      end
    end)
  end

  defp create_candidate(user, result) do
    attrs = %{
      "amount" => result.amount,
      "type" => result.type,
      "transaction_date" => result.transaction_date,
      "description" => result.description,
      "merchant" => result.merchant,
      "raw_description" => result.raw_description,
      "review_reason" => result.review_reason,
      "confidence" => result.confidence,
      "source" => result.source || "email",
      "status" => "pending_review",
      "external_id" => result.external_id
    }

    case Finance.create_transaction(user, attrs) do
      {:ok, transaction} ->
        {:ok, transaction}

      {:error, changeset} ->
        if "has already been taken" in List.wrap(errors_on(changeset).external_id) do
          {:error, :duplicate_external_id}
        else
          {:error, changeset}
        end
    end
  end

  defp map_get(attrs, key) do
    atom_key =
      case key do
        "provider" -> :provider
        "message_id" -> :message_id
        "from" -> :from
        "subject" -> :subject
        "received_at" -> :received_at
        "text_body" -> :text_body
        "html_body" -> :html_body
      end

    Map.get(attrs, key) || Map.get(attrs, atom_key)
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

defmodule Core.Finance.EmailIngestion do
  @moduledoc """
  Converts supported email alerts into pending-review transactions.
  """

  import Ecto.Query, warn: false

  alias Core.Accounts.User
  alias Core.Finance
  alias Core.Finance.{EmailIngestionAttempt, EmailMessage, EmailParserResult, Transaction}
  alias Core.Finance.Parsers.BankAlertParser
  alias Core.Repo

  @parsers [BankAlertParser]

  def ingest(%User{} = user, attrs) when is_map(attrs) do
    message = build_message(attrs)

    case parse_message(message) do
      {:ok, parser, %EmailParserResult{} = result} ->
        case create_candidate(user, result) do
          {:ok, transaction} ->
            record_attempt!(user, message, "created",
              parser_name: parser_name(parser),
              transaction_id: transaction.id
            )

            {:ok, transaction}

          {:error, :duplicate_external_id} ->
            transaction = get_transaction_by_external_id(user, result.external_id)

            record_attempt!(user, message, "duplicate",
              parser_name: parser_name(parser),
              transaction_id: transaction && transaction.id,
              error_reason: "duplicate_external_id"
            )

            {:ok, :duplicate}

          {:error, %Ecto.Changeset{} = changeset} = error ->
            record_attempt!(user, message, "invalid_transaction",
              parser_name: parser_name(parser),
              error_reason: changeset_error_summary(changeset)
            )

            error
        end

      :no_match ->
        record_attempt!(user, message, "unsupported_email", error_reason: "unsupported_email")
        {:error, :unsupported_email}

      {:error, parser, reason} ->
        record_attempt!(user, message, "unparseable_email",
          parser_name: parser_name(parser),
          error_reason: to_string(reason)
        )

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
        {:ok, %EmailParserResult{} = result} -> {:halt, {:ok, parser, result}}
        {:error, reason} -> {:halt, {:error, parser, reason}}
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

  defp record_attempt!(user, message, status, opts) do
    %EmailIngestionAttempt{user_id: user.id}
    |> EmailIngestionAttempt.changeset(%{
      "provider" => truncate(message.provider, 120),
      "message_id" => truncate(message.message_id, 255),
      "sender" => truncate(message.from, 255),
      "subject" => truncate(message.subject, 500),
      "received_at" => normalize_received_at(message.received_at),
      "parser_name" => truncate(Keyword.get(opts, :parser_name), 255),
      "status" => status,
      "error_reason" => truncate(Keyword.get(opts, :error_reason), 500),
      "body_snippet" => message |> message_body() |> truncate(1000),
      "transaction_id" => Keyword.get(opts, :transaction_id)
    })
    |> Repo.insert!()
  end

  defp get_transaction_by_external_id(_user, nil), do: nil

  defp get_transaction_by_external_id(user, external_id) do
    Transaction
    |> where([transaction], transaction.user_id == ^user.id)
    |> where([transaction], transaction.external_id == ^external_id)
    |> Repo.one()
  end

  defp normalize_received_at(%DateTime{} = value), do: DateTime.truncate(value, :second)

  defp normalize_received_at(%NaiveDateTime{} = value) do
    value
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.truncate(:second)
  end

  defp normalize_received_at(_value), do: nil

  defp message_body(%EmailMessage{text_body: text_body, html_body: html_body}) do
    text_body || html_body
  end

  defp parser_name(nil), do: nil
  defp parser_name(parser), do: inspect(parser)

  defp changeset_error_summary(changeset) do
    changeset
    |> errors_on()
    |> Enum.map(fn {field, messages} -> "#{field}: #{Enum.join(messages, ", ")}" end)
    |> Enum.join("; ")
  end

  defp truncate(nil, _limit), do: nil

  defp truncate(value, limit) do
    value
    |> to_string()
    |> String.slice(0, limit)
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

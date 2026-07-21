defmodule CoreWeb.Api.Finance.ServiceEmailIngestionController do
  use CoreWeb, :controller

  alias Core.Finance

  def create(conn, %{"ingestion_token" => token} = params) do
    case Finance.user_for_ingestion_token(token) do
      {:ok, user} ->
        attrs =
          params
          |> email_attrs()
          |> normalize_received_at()

        case Finance.ingest_email_transaction_candidate(user, attrs) do
          {:ok, :duplicate} ->
            conn
            |> put_status(:ok)
            |> json(%{status: "duplicate"})

          {:ok, transaction} ->
            conn
            |> put_status(:created)
            |> json(%{status: "created", transaction: serialize_transaction(transaction)})

          {:error, :unsupported_email} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "unsupported_email"})

          {:error, :unparseable_email} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "unparseable_email"})

          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "invalid_transaction", details: errors_on(changeset)})
        end

      {:error, :not_found} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_ingestion_token"})
    end
  end

  def create(conn, _params),
    do: conn |> put_status(:bad_request) |> json(%{error: "missing_ingestion_token"})

  defp email_attrs(%{"email" => attrs}) when is_map(attrs), do: attrs
  defp email_attrs(attrs), do: attrs

  defp normalize_received_at(attrs) do
    Map.update(attrs, "received_at", nil, &parse_received_at/1)
  end

  defp parse_received_at(%DateTime{} = value), do: value
  defp parse_received_at(%NaiveDateTime{} = value), do: value
  defp parse_received_at(nil), do: nil

  defp parse_received_at(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} ->
        datetime

      {:error, _reason} ->
        parse_naive_received_at(value)
    end
  end

  defp parse_received_at(value), do: value

  defp parse_naive_received_at(value) do
    case NaiveDateTime.from_iso8601(value) do
      {:ok, naive_datetime} -> naive_datetime
      {:error, _reason} -> value
    end
  end

  defp serialize_transaction(transaction) do
    %{
      id: transaction.id,
      amount: Decimal.to_string(transaction.amount),
      type: transaction.type,
      source: transaction.source,
      status: transaction.status,
      description: transaction.description,
      merchant: transaction.merchant,
      external_id: transaction.external_id,
      transaction_date: Date.to_iso8601(transaction.transaction_date),
      review_reason: transaction.review_reason
    }
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

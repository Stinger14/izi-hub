defmodule CoreWeb.ServiceAuth do
  @moduledoc """
  Bearer-token check for service-to-service API calls.

  Context: guards the email ingestion service routes; compares the
  `Authorization: Bearer` header with `:finance_ingestion_api_key` in
  constant time and answers 401 JSON otherwise.
  """

  import Plug.Conn

  @doc "Plug init (no options)."
  def init(opts), do: opts

  @doc "Passes requests with the right bearer token; halts others with 401."
  def call(conn, _opts) do
    expected = Application.fetch_env!(:core, :finance_ingestion_api_key)

    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         true <- Plug.Crypto.secure_compare(token, expected) do
      conn
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "unauthenticated"})
        |> halt()
    end
  end
end

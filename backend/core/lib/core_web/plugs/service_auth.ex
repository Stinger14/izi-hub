defmodule CoreWeb.ServiceAuth do
  import Plug.Conn

  def init(opts), do: opts

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

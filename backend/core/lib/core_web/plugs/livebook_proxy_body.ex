defmodule CoreWeb.LivebookProxyBody do
  @moduledoc false

  @behaviour Plug

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if form_encoded?(conn) and map_size(conn.body_params) > 0 do
      body = Plug.Conn.Query.encode(conn.body_params)
      assign(conn, :raw_body, body)
    else
      conn
    end
  end

  defp form_encoded?(conn) do
    case get_req_header(conn, "content-type") do
      [content_type | _] -> String.starts_with?(content_type, "application/x-www-form-urlencoded")
      [] -> false
    end
  end
end

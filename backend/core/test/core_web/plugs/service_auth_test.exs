defmodule CoreWeb.ServiceAuthTest do
  use CoreWeb.ConnCase, async: true

  alias CoreWeb.ServiceAuth

  setup do
    expected_key = Application.fetch_env!(:core, :finance_ingestion_api_key)
    %{expected_key: expected_key}
  end

  test "passes a request through unchanged when the bearer token matches", %{
    conn: conn,
    expected_key: expected_key
  } do
    conn =
      conn
      |> put_req_header("authorization", "Bearer " <> expected_key)
      |> ServiceAuth.call(ServiceAuth.init([]))

    refute conn.halted
  end

  test "halts with 401 when the authorization header is missing", %{conn: conn} do
    conn = ServiceAuth.call(conn, ServiceAuth.init([]))

    assert conn.halted
    assert conn.status == 401
    assert json_response(conn, 401)["error"] == "unauthenticated"
  end

  test "halts with 401 when the header is missing the Bearer prefix", %{
    conn: conn,
    expected_key: expected_key
  } do
    conn =
      conn
      |> put_req_header("authorization", expected_key)
      |> ServiceAuth.call(ServiceAuth.init([]))

    assert conn.halted
    assert conn.status == 401
  end

  test "halts with 401 when the token doesn't match", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer wrong-token")
      |> ServiceAuth.call(ServiceAuth.init([]))

    assert conn.halted
    assert conn.status == 401
    assert json_response(conn, 401)["error"] == "unauthenticated"
  end
end

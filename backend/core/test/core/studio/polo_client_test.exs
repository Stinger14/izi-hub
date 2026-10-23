defmodule Core.Studio.PoloClientTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Core.Studio.{Piece, PoloClient}

  @piece %Piece{title: "Mangú", notes: nil, transcript: nil, language: "es", kind: "reel"}

  # Answers the next request with `fun` and sends the decoded request to the test.
  defp stub(fun) do
    test = self()

    Req.Test.stub(PoloClient, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test, {:request, conn.request_path, Jason.decode!(body), conn})
      fun.(conn)
    end)
  end

  test "hooks sends the title when there are no notes and returns the body" do
    stub(&Req.Test.json(&1, %{"hooks" => [%{"text" => "¿Sabías?", "angle" => "question"}]}))

    assert {:ok, %{"hooks" => [%{"text" => "¿Sabías?"}]}} = PoloClient.hooks(@piece)

    assert_received {:request, "/api/v1/write/hooks",
                     %{"topic" => "Mangú", "language" => "es", "kind" => "reel"}, conn}

    assert ["Bearer " <> _] = Plug.Conn.get_req_header(conn, "authorization")
  end

  test "script prefers notes over the title" do
    stub(&Req.Test.json(&1, %{}))

    PoloClient.script(%{@piece | notes: "Tres golpes"})

    assert_received {:request, "/api/v1/write/script", %{"topic" => "Tres golpes"}, _conn}
  end

  test "caption prefers the transcript, then notes, then the title" do
    stub(&Req.Test.json(&1, %{}))

    PoloClient.caption(%{@piece | notes: "notes", transcript: "transcript"})
    assert_received {:request, "/api/v1/write/caption", %{"source" => "transcript"}, _}

    PoloClient.caption(%{@piece | notes: "notes"})
    assert_received {:request, "/api/v1/write/caption", %{"source" => "notes"}, _}
  end

  test "passes the service's detail message through" do
    stub(fn conn ->
      conn
      |> Plug.Conn.put_status(422)
      |> Req.Test.json(%{"detail" => "The AI declined to write this."})
    end)

    assert {:error, {422, "The AI declined to write this."}} = PoloClient.caption(@piece)
  end

  test "falls back to a generic message without a detail" do
    stub(&Plug.Conn.send_resp(&1, 500, "boom"))

    assert {:error, {500, "Polo Studio returned 500. Try again."}} = PoloClient.hooks(@piece)
  end

  test "reports an unreachable service" do
    stub(&Req.Test.transport_error(&1, :econnrefused))

    log =
      capture_log(fn ->
        assert {:error, {:unreachable, "Polo Studio is unreachable. Try again later."}} =
                 PoloClient.hooks(@piece)
      end)

    # Exception.message/1 renders :econnrefused as "connection refused"
    assert log =~ "/api/v1/write/hooks failed: connection refused"
  end
end

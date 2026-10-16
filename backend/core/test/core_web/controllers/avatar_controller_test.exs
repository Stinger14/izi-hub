defmodule CoreWeb.AvatarControllerTest do
  use CoreWeb.ConnCase, async: true

  alias Core.Accounts

  @png <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, "rest-of-png">>

  test "serves the stored image with its type, nosniff and a long cache", %{conn: conn} do
    {:ok, owner} = Accounts.put_user_avatar(user_fixture(), @png)

    conn = conn |> log_in_user(user_fixture()) |> get(~p"/avatars/#{owner.id}")

    assert response(conn, 200) == @png
    assert response_content_type(conn, :png)
    assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    assert [cache] = get_resp_header(conn, "cache-control")
    assert cache =~ "immutable"
  end

  test "404s without a photo or with a bad id", %{conn: conn} do
    conn = log_in_user(conn, user_fixture())

    assert conn |> get(~p"/avatars/#{user_fixture().id}") |> response(404)
    assert conn |> get(~p"/avatars/not-a-uuid") |> response(404)
  end

  test "needs sign-in", %{conn: conn} do
    {:ok, owner} = Accounts.put_user_avatar(user_fixture(), @png)

    assert conn |> get(~p"/avatars/#{owner.id}") |> redirected_to() == "/login?error=auth"
  end
end

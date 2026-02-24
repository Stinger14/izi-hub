defmodule CoreWeb.PasswordSetupControllerTest do
  use CoreWeb.ConnCase, async: true

  alias Core.Accounts

  describe "GET /set-password" do
    test "renders setup page for valid token", %{conn: conn} do
      {:ok, _user, token} =
        Accounts.register_email_only_user(
          "setup_get_#{System.unique_integer([:positive])}@example.com"
        )

      conn = get(conn, ~p"/set-password?token=#{token}")
      html = html_response(conn, 200)

      assert html =~ "Complete your account"
      assert html =~ "Username"
    end

    test "redirects for invalid token", %{conn: conn} do
      conn = get(conn, ~p"/set-password?token=invalid-token")

      assert redirected_to(conn) == "/hub?auth=signup"
    end
  end

  describe "POST /set-password" do
    test "sets password and signs user in", %{conn: conn} do
      email = "setup_post_#{System.unique_integer([:positive])}@example.com"
      {:ok, user, token} = Accounts.register_email_only_user(email)

      conn =
        post(conn, ~p"/set-password", %{
          "user" => %{"token" => token, "password" => "Password123!"}
        })

      assert redirected_to(conn) == ~p"/hub"
      assert get_session(conn, :user_id) == user.id
      assert :error == Accounts.get_user_by_token(token, "setup_password")
      assert Accounts.get_user_by_email_password(email, "Password123!")
    end

    test "renders password validation errors", %{conn: conn} do
      {:ok, _user, token} =
        Accounts.register_email_only_user(
          "setup_errors_#{System.unique_integer([:positive])}@example.com"
        )

      conn =
        post(conn, ~p"/set-password", %{
          "user" => %{"token" => token, "password" => "short"}
        })

      html = html_response(conn, 200)
      assert html =~ "Password"
    end

    test "redirects when token is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/set-password", %{
          "user" => %{"token" => "invalid-token", "password" => "Password123!"}
        })

      assert redirected_to(conn) == "/hub?auth=signup"
    end
  end
end

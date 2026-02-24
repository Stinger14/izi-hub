defmodule CoreWeb.RegistrationControllerTest do
  use CoreWeb.ConnCase, async: true

  alias Core.Accounts

  describe "GET /signup" do
    test "redirects to hub signup inline panel", %{conn: conn} do
      conn = get(conn, ~p"/signup")

      assert redirected_to(conn) == "/hub?auth=signup"
    end
  end

  describe "POST /signup" do
    test "creates account and redirects to password setup", %{conn: conn} do
      attrs = %{
        "email" => "signup_#{System.unique_integer([:positive])}@example.com"
      }

      conn = post(conn, ~p"/signup", %{"user" => attrs})
      user = Accounts.get_user_by_email(attrs["email"])
      redirect_path = redirected_to(conn)
      uri = URI.parse(redirect_path)
      params = URI.decode_query(uri.query || "")

      assert uri.path == "/set-password"
      assert is_binary(params["token"])
      assert user != nil
      assert user.username =~ ~r/^[a-z]+-[a-z]+-[a-z]+$/
      assert get_session(conn, :user_id) == nil
    end

    test "renders errors for invalid attrs", %{conn: conn} do
      conn =
        post(conn, ~p"/signup", %{
          "user" => %{"email" => ""}
        })

      assert redirected_to(conn) == "/hub?auth=signup"
    end
  end
end

defmodule CoreWeb.SessionControllerTest do
  use CoreWeb.ConnCase, async: true

  alias Core.Accounts
  alias Core.Repo

  describe "GET /login" do
    test "redirects to hub login inline panel", %{conn: conn} do
      conn = get(conn, ~p"/login")

      assert redirected_to(conn) == "/hub?auth=login"
    end

    test "shows admin and logout links for admin scope on controller-rendered pages", %{
      conn: conn
    } do
      {:ok, user} =
        Accounts.register_user(%{
          email: "admin_nav_#{System.unique_integer([:positive])}@example.com",
          password: "Password123!",
          username: "admin_nav_#{System.unique_integer([:positive])}",
          full_name: "Admin Nav User"
        })

      user
      |> Ecto.Changeset.change(%{role: "admin"})
      |> Repo.update!()

      {:ok, _pending_user, token} =
        Accounts.register_email_only_user(
          "admin_nav_pending_#{System.unique_integer([:positive])}@example.com"
        )

      conn =
        conn
        |> init_test_session(%{user_id: user.id})
        |> get(~p"/set-password?token=#{token}")

      html = html_response(conn, 200)
      assert html =~ "Admin"
      assert html =~ "Logout"
    end
  end

  describe "POST /login" do
    test "sets session for valid user credentials and redirects to hub", %{conn: conn} do
      {:ok, user} =
        Accounts.register_user(%{
          email: "login_user_#{System.unique_integer([:positive])}@example.com",
          password: "Password123!",
          username: "login_user_#{System.unique_integer([:positive])}",
          full_name: "Login User"
        })

      conn =
        post(conn, ~p"/login", %{
          "user" => %{"email" => user.email, "password" => "Password123!"}
        })

      assert redirected_to(conn) == ~p"/hub"
      assert get_session(conn, :user_id) == user.id
    end

    test "sets session for admin credentials and redirects to admin", %{conn: conn} do
      {:ok, user} =
        Accounts.register_user(%{
          email: "admin_login_#{System.unique_integer([:positive])}@example.com",
          password: "Password123!",
          username: "admin_login_#{System.unique_integer([:positive])}",
          full_name: "Admin Login User"
        })

      user
      |> Ecto.Changeset.change(%{role: "admin"})
      |> Repo.update!()

      conn =
        post(conn, ~p"/login", %{
          "user" => %{"email" => user.email, "password" => "Password123!"}
        })

      assert redirected_to(conn) == ~p"/admin"
      assert get_session(conn, :user_id) == user.id
    end

    test "rejects invalid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/login", %{
          "user" => %{"email" => "wrong@example.com", "password" => "wrong-password"}
        })

      assert redirected_to(conn) == "/hub?auth=login"
      assert get_session(conn, :user_id) == nil
    end
  end

  describe "DELETE /logout" do
    test "drops session", %{conn: conn} do
      logout_conn =
        conn
        |> init_test_session(%{user_id: Ecto.UUID.generate()})
        |> delete(~p"/logout")

      conn =
        logout_conn
        |> recycle()
        |> get(~p"/hub")

      assert redirected_to(logout_conn) == ~p"/hub"
      assert get_session(conn, :user_id) == nil
    end
  end
end

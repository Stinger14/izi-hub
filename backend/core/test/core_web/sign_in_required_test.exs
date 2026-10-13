defmodule CoreWeb.SignInRequiredTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "signed-out visitors" do
    test "opening the hub lands on the welcome page without an error", %{conn: conn} do
      conn = get(conn, ~p"/hub")
      assert redirected_to(conn) == ~p"/welcome"
      refute Phoenix.Flash.get(conn.assigns.flash, :error)

      assert {:error, {:redirect, %{to: "/welcome"}}} = live(build_conn(), ~p"/hub")
    end

    test "pages that need an account send them to sign in", %{conn: conn} do
      for path <- ["/resources", "/liveapps", "/finance", "/office", "/settings", "/notebooks"] do
        conn = get(conn, path)
        assert redirected_to(conn) == ~p"/login?error=auth", path
      end
    end

    test "the welcome page, profile and CV stay public", %{conn: conn} do
      assert {:ok, _view, _html} = live(conn, ~p"/welcome")
      assert {:ok, _view, _html} = live(conn, ~p"/profile")
      refute get(conn, ~p"/cv").status in [301, 302]
    end

    test "the header offers sign in and the logo points to the welcome page", %{conn: conn} do
      html = conn |> get(~p"/welcome") |> html_response(200)
      assert html =~ ~s(id="header-sign-in")
      refute html =~ ~s(id="header-account-link")
      assert html =~ ~s(href="/welcome" class="font-display)
    end

    test "the site root goes to the welcome page", %{conn: conn} do
      assert conn |> get(~p"/") |> redirected_to() == ~p"/welcome"
    end
  end

  describe "returning after sign-in" do
    test "goes back to the page that asked for it", %{conn: conn} do
      user = user_fixture()

      conn = get(conn, ~p"/finance?section=budgets")
      assert redirected_to(conn) == ~p"/login?error=auth"

      conn =
        post(conn, ~p"/login", %{
          "user" => %{"email" => user.email, "password" => valid_password()}
        })

      assert redirected_to(conn) == "/finance?section=budgets"

      # Used once: the next sign-in goes to the default page again.
      conn = conn |> recycle() |> delete(~p"/logout")

      conn =
        post(recycle(conn), ~p"/login", %{
          "user" => %{"email" => user.email, "password" => valid_password()}
        })

      assert redirected_to(conn) == ~p"/hub"
    end

    test "ignores a stored path that points to another site", %{conn: conn} do
      user = user_fixture()

      for evil <- ["//evil.example/phish", "/\\\\evil.example", "https://evil.example"] do
        conn =
          conn
          |> init_test_session(user_return_to: evil)
          |> post(~p"/login", %{
            "user" => %{"email" => user.email, "password" => valid_password()}
          })

        assert redirected_to(conn) == ~p"/hub", evil
      end
    end
  end

  describe "signed-in users" do
    test "the site root goes to the hub", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())
      assert conn |> get(~p"/") |> redirected_to() == ~p"/hub"
    end

    test "the header logo points to the hub", %{conn: conn} do
      html = conn |> log_in_user(user_fixture()) |> get(~p"/welcome") |> html_response(200)
      assert html =~ ~s(href="/hub" class="font-display)
      refute html =~ ~s(id="header-sign-in")
    end
  end
end

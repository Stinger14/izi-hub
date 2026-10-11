defmodule CoreWeb.FlashTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.Finance

  describe "LiveView pages" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: init_test_session(conn, user_id: user.id), user: user}
    end

    test "an info flash is shown as a dismissable status toast", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/finance")
      render_click(view, "show_section", %{"section" => "accounts"})

      html =
        view
        |> form("#account-section-form",
          account: %{
            "name" => "Checking",
            "kind" => "checking",
            "currency" => "DOP",
            "current_balance" => "10"
          }
        )
        |> render_submit()

      assert html =~ ~s(id="flash-info")
      assert html =~ ~s(role="status")
      assert html =~ "Account added"
      assert html =~ ~s(data-flash-autodismiss="5000")
    end

    test "dismissing clears the flash on the server", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/finance")
      render_click(view, "show_section", %{"section" => "accounts"})

      view
      |> form("#account-section-form",
        account: %{
          "name" => "Checking",
          "kind" => "checking",
          "currency" => "DOP",
          "current_balance" => "10"
        }
      )
      |> render_submit()

      html = view |> element("#flash-info button[data-flash-dismiss]") |> render_click()
      refute html =~ "Account added"
    end

    test "an error flash is an alert that doesn't auto-dismiss", %{conn: conn, user: user} do
      {:ok, a} =
        Finance.create_account(user, %{
          "name" => "Alpha",
          "kind" => "checking",
          "current_balance" => "10"
        })

      {:ok, b} =
        Finance.create_account(user, %{
          "name" => "Bravo",
          "kind" => "checking",
          "current_balance" => "10"
        })

      {:ok, view, _html} = live(conn, ~p"/finance")

      html =
        view
        |> form("#quick-send-form",
          transfer: %{"from_account_id" => a.id, "to_account_id" => b.id, "amount" => "-1"}
        )
        |> render_submit()

      assert html =~ ~s(id="flash-error")
      assert html =~ ~s(role="alert")
      assert html =~ "Enter an amount above zero"

      [error_toast] =
        html |> LazyHTML.from_fragment() |> LazyHTML.query("#flash-error") |> Enum.to_list()

      assert LazyHTML.attribute(error_toast, "data-flash-autodismiss") == []
    end

    test "a successful transfer confirms with a flash", %{conn: conn, user: user} do
      {:ok, a} =
        Finance.create_account(user, %{
          "name" => "Alpha",
          "kind" => "checking",
          "current_balance" => "10"
        })

      {:ok, b} =
        Finance.create_account(user, %{
          "name" => "Bravo",
          "kind" => "checking",
          "current_balance" => "10"
        })

      {:ok, view, _html} = live(conn, ~p"/finance")

      html =
        view
        |> form("#quick-send-form",
          transfer: %{"from_account_id" => a.id, "to_account_id" => b.id, "amount" => "5"}
        )
        |> render_submit()

      assert html =~ "Transfer recorded"
    end
  end

  describe "controller-rendered pages" do
    test "a flash from a redirect is shown on the next page", %{conn: conn} do
      conn = get(conn, ~p"/set-password?token=invalid-token")
      assert redirected_to(conn) == "/signup"

      html = conn |> recycle() |> get(~p"/signup") |> html_response(200)

      assert html =~ ~s(id="flash-error")
      assert html =~ "Password setup link is invalid or expired"
    end
  end
end

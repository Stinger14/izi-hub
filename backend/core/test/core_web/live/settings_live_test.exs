defmodule CoreWeb.SettingsLiveTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.{Accounts, Repo}
  alias Core.Accounts.User

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: init_test_session(conn, user_id: user.id), user: user}
  end

  test "requires sign-in" do
    assert {:error, {:redirect, %{to: to}}} = live(build_conn(), ~p"/settings")
    assert to =~ "/login"
  end

  test "the header's username chip links to settings", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/hub")

    assert html
           |> LazyHTML.from_document()
           |> LazyHTML.query(~s(a#header-account-link[href="/settings"]))
           |> Enum.count() == 1
  end

  test "updates the profile and the header right away", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    html =
      view
      |> form("#profile-form", profile: %{full_name: "Ana Pérez", username: "ana_settings"})
      |> render_submit()

    assert html =~ "Profile updated"
    assert html =~ "ana_settings"
    assert %User{full_name: "Ana Pérez", username: "ana_settings"} = Repo.get!(User, user.id)
  end

  test "shows a taken username inline", %{conn: conn} do
    other = user_fixture()
    {:ok, view, _html} = live(conn, ~p"/settings")

    html = view |> form("#profile-form", profile: %{username: other.username}) |> render_submit()
    assert html =~ "Username has already been taken"
  end

  test "can't escalate the role through the form", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    render_submit(view, "save_profile", %{
      "profile" => %{"username" => "sneaky", "role" => "admin", "is_active" => "false"}
    })

    reloaded = Repo.get!(User, user.id)
    assert reloaded.role == user.role
    assert reloaded.is_active == user.is_active
  end

  test "links and unlinks GitHub", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    assert view |> form("#github-form", github: %{github_username: "octocat"}) |> render_submit() =~
             "GitHub account linked"

    assert Repo.get!(User, user.id).github_username == "octocat"

    assert view |> form("#github-form", github: %{github_username: ""}) |> render_submit() =~
             "GitHub account removed"

    assert Repo.get!(User, user.id).github_username == nil
  end

  test "changes email only with the current password", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    html =
      view
      |> form("#email-form",
        email: %{email: "moved@example.com", current_password: "Wrong-pass1"}
      )
      |> render_submit()

    assert html =~ "Current password is not valid"
    assert Repo.get!(User, user.id).email == user.email

    html =
      view
      |> form("#email-form",
        email: %{email: "moved@example.com", current_password: valid_password()}
      )
      |> render_submit()

    assert html =~ "Email updated"
    assert Repo.get!(User, user.id).email == "moved@example.com"
  end

  test "changes the password, never echoing it back", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    html =
      view
      |> form("#password-form",
        password: %{
          current_password: valid_password(),
          password: "Fresh-2026x",
          password_confirmation: "Mismatch-1"
        }
      )
      |> render_submit()

    assert html =~ "Confirm new password does not match password"
    refute html =~ "Fresh-2026x"

    html =
      view
      |> form("#password-form",
        password: %{
          current_password: valid_password(),
          password: "Fresh-2026x",
          password_confirmation: "Fresh-2026x"
        }
      )
      |> render_submit()

    assert html =~ "Password changed"
    assert Accounts.get_user_by_email_password(user.email, "Fresh-2026x")
  end
end

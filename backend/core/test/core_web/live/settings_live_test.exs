defmodule CoreWeb.SettingsLiveTest do
  use CoreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Core.{Accounts, Repo}
  alias Core.Accounts.User

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  test "requires sign-in" do
    assert {:error, {:redirect, %{to: to}}} = live(build_conn(), ~p"/settings")
    assert to =~ "/login"
  end

  test "the header's account menu links to settings and signs out", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/hub")

    assert has_element?(view, ~s(#account-menu a#account-menu-settings[href="/settings"]))
    assert has_element?(view, "#account-menu button#account-menu-sign-out", "Sign out")
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

  describe "profile photo" do
    @png <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, "rest-of-png">>

    test "uploads a photo and shows it in the header", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/settings")
      refute has_element?(view, "#account-menu-trigger img")

      avatar =
        file_input(view, "#avatar-form", :avatar, [
          %{name: "me.png", content: @png, type: "image/png"}
        ])

      render_upload(avatar, "me.png")

      assert render(view) =~ "Photo updated"
      assert has_element?(view, "#account-menu-trigger img[src^='/avatars/#{user.id}?v=']")
      assert has_element?(view, "#avatar-remove")
      assert Core.Accounts.get_user_avatar(user.id).content_type == "image/png"
    end

    test "rejects a file that only claims to be an image", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      avatar =
        file_input(view, "#avatar-form", :avatar, [
          %{name: "fake.png", content: "not really a png", type: "image/png"}
        ])

      render_upload(avatar, "fake.png")

      assert view |> element("#avatar-error") |> render() =~ "a JPEG, PNG, GIF or WebP image"
      assert Core.Accounts.get_user_avatar(user.id) == nil
    end

    test "rejects other file types before uploading", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      avatar =
        file_input(view, "#avatar-form", :avatar, [
          %{name: "logo.svg", content: "<svg/>", type: "image/svg+xml"}
        ])

      assert {:error, [[_ref, :not_accepted]]} = render_upload(avatar, "logo.svg")
    end

    test "removes the photo", %{conn: conn, user: user} do
      {:ok, _} = Core.Accounts.put_user_avatar(user, @png)
      {:ok, view, _html} = live(conn, ~p"/settings")

      view |> element("#avatar-remove") |> render_click()

      refute has_element?(view, "#account-menu-trigger img")
      assert Core.Accounts.get_user_avatar(user.id) == nil
    end
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

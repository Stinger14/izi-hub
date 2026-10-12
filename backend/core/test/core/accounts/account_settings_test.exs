defmodule Core.Accounts.AccountSettingsTest do
  use Core.DataCase, async: true

  alias Core.Accounts
  alias Core.Accounts.User

  setup do
    %{user: user_fixture()}
  end

  describe "update_account_profile/2" do
    test "updates name and username", %{user: user} do
      assert {:ok, user} =
               Accounts.update_account_profile(user, %{
                 "full_name" => " Ana Pérez ",
                 "username" => "ana_p"
               })

      assert user.full_name == "Ana Pérez"
      assert user.username == "ana_p"
    end

    test "rejects a taken or malformed username", %{user: user} do
      other = user_fixture()

      assert {:error, changeset} =
               Accounts.update_account_profile(user, %{"username" => other.username})

      assert "has already been taken" in errors_on(changeset).username

      assert {:error, changeset} =
               Accounts.update_account_profile(user, %{"username" => "no spaces"})

      assert errors_on(changeset).username != []
    end

    test "ignores role, status and verification fields", %{user: user} do
      {:ok, updated} =
        Accounts.update_account_profile(user, %{
          "username" => "still_member",
          "role" => "admin",
          "is_active" => false,
          "email_verified" => true
        })

      reloaded = Repo.get!(User, user.id)
      assert reloaded.role == user.role
      assert reloaded.email_verified == user.email_verified
      assert Map.get(reloaded, :is_active) == Map.get(user, :is_active)
      assert updated.username == "still_member"
    end
  end

  describe "change_user_email/3" do
    test "changes the email with the current password and marks it unverified", %{user: user} do
      assert {:ok, user} =
               Accounts.change_user_email(user, valid_password(), %{
                 "email" => "new-address@example.com"
               })

      assert user.email == "new-address@example.com"
      refute user.email_verified
    end

    test "rejects a wrong password, an unchanged email and a taken email", %{user: user} do
      assert {:error, cs} =
               Accounts.change_user_email(user, "wrong-Pass1", %{"email" => "x@example.com"})

      assert errors_on(cs).current_password == ["is not valid"]

      assert {:error, cs} =
               Accounts.change_user_email(user, valid_password(), %{"email" => user.email})

      assert errors_on(cs).email == ["did not change"]

      other = user_fixture()

      assert {:error, cs} =
               Accounts.change_user_email(user, valid_password(), %{"email" => other.email})

      assert "has already been taken" in errors_on(cs).email
      assert Repo.get!(User, user.id).email == user.email
    end
  end

  describe "change_user_password/3" do
    test "changes the password with the current one and a matching confirmation", %{user: user} do
      attrs = %{"password" => "NewPass-2026", "password_confirmation" => "NewPass-2026"}
      assert {:ok, _} = Accounts.change_user_password(user, valid_password(), attrs)
      assert Accounts.get_user_by_email_password(user.email, "NewPass-2026")
      refute Accounts.get_user_by_email_password(user.email, valid_password())
    end

    test "rejects a wrong current password, a mismatch and a weak password", %{user: user} do
      assert {:error, cs} =
               Accounts.change_user_password(user, "wrong-Pass1", %{
                 "password" => "NewPass-2026",
                 "password_confirmation" => "NewPass-2026"
               })

      assert errors_on(cs).current_password == ["is not valid"]

      assert {:error, cs} =
               Accounts.change_user_password(user, valid_password(), %{
                 "password" => "NewPass-2026",
                 "password_confirmation" => "Other-2026"
               })

      assert errors_on(cs).password_confirmation == ["does not match password"]

      assert {:error, cs} =
               Accounts.change_user_password(user, valid_password(), %{
                 "password" => "short",
                 "password_confirmation" => "short"
               })

      assert errors_on(cs).password != []
      assert Accounts.get_user_by_email_password(user.email, valid_password())
    end
  end
end

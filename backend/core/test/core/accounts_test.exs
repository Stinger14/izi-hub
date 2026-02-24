defmodule Core.AccountsTest do
  use Core.DataCase

  alias Core.Accounts
  alias Core.Accounts.User

  describe "User Registration" do
    test "Register a user with valid attributes" do
      attrs = %{
        email: "test@example.com",
        password: "Password123!",
        username: "testuser",
        full_name: "Test User"
      }

      assert {:ok, %User{} = user} = Accounts.register_user(attrs)
      assert user.email == "test@example.com"
      assert user.username == "testuser"
      assert user.full_name == "Test User"
      assert user.hashed_password != nil
    end

    test "Does not register a user with invalid attributes" do
      attrs = %{
        email: "",
        password: "",
        username: "",
        full_name: ""
      }

      assert {:error, changeset} = Accounts.register_user(attrs)
      assert changeset.errors[:email] != nil
      assert changeset.errors[:password] != nil
      assert changeset.errors[:username] != nil
    end
  end

  describe "User Authentication" do
    setup do
      attrs = %{
        email: "auth_user@example.com",
        password: "Password123!",
        username: "authuser",
        full_name: "Auth User"
      }

      {:ok, user} = Accounts.register_user(attrs)
      %{user: user}
    end

    test "Authenticate a user with valid credentials", %{user: user} do
      assert authenticated_user = Accounts.get_user_by_email_password(user.email, "Password123!")
      assert authenticated_user.id == user.id
    end

    test "Authenticate a user with invalid credentials", %{user: user} do
      assert Accounts.get_user_by_email_password(user.email, "Wrong Password") == nil
    end

    # test "does not authenticate user with non-existent email" do
    #   assert Accounts.get_user_by_email_and_password("nonexistent@example.com", "Password123!") ==
    #            nil
    # end
  end

  describe "User Profile Updates" do
    setup do
      attrs = %{
        email: "update_user@example.com",
        password: "Password123!",
        username: "updateuser",
        full_name: "Update User"
      }

      {:ok, user} = Accounts.register_user(attrs)
      %{user: user}
    end

    test "updates user profile", %{user: user} do
      attrs = %{full_name: "Updated User"}
      assert {:ok, updated_user} = Accounts.update_user_profile(user, attrs)
      assert updated_user.full_name == "Updated User"
    end

    test "does not update profile with invalid attributes", %{user: user} do
      attrs = %{username: ""}
      assert {:error, changeset} = Accounts.update_user_profile(user, attrs)
      assert changeset.errors[:username] != nil
    end
  end

  describe "Valid Token Generation" do
    setup do
      attrs = %{
        email: "token_user@example.com",
        password: "Password123!",
        username: "tokenuser",
        full_name: "Token User"
      }

      {:ok, user} = Accounts.register_user(attrs)
      %{user: user}
    end

    test "generates valid access token", %{user: user} do
      token = Accounts.generate_access_token(user)
      assert {:ok, verified_user} = Accounts.get_user_by_token(token, "access")
      assert verified_user.id == user.id
    end

    test "does not verify invalid token" do
      assert :error = Accounts.get_user_by_token("invalid_token", "access")
    end
  end

  describe "Delete User" do
    setup do
      attrs = %{
        email: "delete_user@example.com",
        password: "Password123!",
        username: "deleteuser",
        full_name: "Delete User"
      }

      {:ok, user} = Accounts.register_user(attrs)
      %{user: user}
    end

    test "deletes a user", %{user: user} do
      assert {:ok, _} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end
  end

  describe "Email-only Registration" do
    test "registers with generated username and setup token" do
      email = "email_only_#{System.unique_integer([:positive])}@example.com"

      assert {:ok, %User{} = user, token} = Accounts.register_email_only_user(email)
      assert user.email == email
      assert user.username =~ ~r/^[a-z]+-[a-z]+-[a-z]+$/
      assert is_binary(token)
      assert {:ok, setup_user} = Accounts.get_user_by_token(token, "setup_password")
      assert setup_user.id == user.id
    end

    test "sets password from setup token" do
      email = "setup_token_#{System.unique_integer([:positive])}@example.com"
      assert {:ok, %User{} = user, token} = Accounts.register_email_only_user(email)

      assert {:ok, updated_user} =
               Accounts.set_password_from_setup_token(token, "Password123!")

      assert updated_user.id == user.id
      assert :error == Accounts.get_user_by_token(token, "setup_password")
      assert Accounts.get_user_by_email_password(email, "Password123!")
    end
  end
end

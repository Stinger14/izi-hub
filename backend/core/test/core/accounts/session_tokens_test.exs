defmodule Core.Accounts.SessionTokensTest do
  use Core.DataCase, async: true

  alias Core.{Accounts, AdminOps}
  alias Core.Accounts.{User, UserToken}

  setup do
    %{user: user_fixture()}
  end

  defp session(user) do
    {token, id} = Accounts.generate_user_session_token(user)
    :ok = Phoenix.PubSub.subscribe(Core.PubSub, Accounts.session_socket_id(id))
    token
  end

  defp assert_disconnected do
    assert_receive %Phoenix.Socket.Broadcast{event: "disconnect"}
  end

  test "a session token signs the user in; only its hash is stored", %{user: user} do
    {token, id} = Accounts.generate_user_session_token(user)
    assert Accounts.get_user_by_session_token(token).id == user.id
    assert Repo.get!(UserToken, id).token != token
    assert Accounts.get_user_by_session_token("not-a-token") == nil
    assert Accounts.get_user_by_session_token(nil) == nil
  end

  test "expired tokens don't sign in", %{user: user} do
    {token, id} = Accounts.generate_user_session_token(user)

    Repo.get!(UserToken, id)
    |> Ecto.Changeset.change(expires_at: ~N[2020-01-01 00:00:00])
    |> Repo.update!()

    assert Accounts.get_user_by_session_token(token) == nil
  end

  test "logout revokes that one session and disconnects it", %{user: user} do
    token = session(user)
    other = Accounts.generate_user_session_token(user) |> elem(0)

    assert :ok = Accounts.delete_user_session_token(token)
    assert_disconnected()
    assert Accounts.get_user_by_session_token(token) == nil
    assert Accounts.get_user_by_session_token(other)
  end

  test "signing out everywhere else keeps the current session", %{user: user} do
    current = Accounts.generate_user_session_token(user) |> elem(0)
    elsewhere = session(user)

    assert Accounts.revoke_user_sessions(user, except: current) == 1
    assert_disconnected()
    assert Accounts.get_user_by_session_token(current)
    assert Accounts.get_user_by_session_token(elsewhere) == nil
  end

  test "changing the password signs out other sessions but not this one", %{user: user} do
    current = Accounts.generate_user_session_token(user) |> elem(0)
    elsewhere = session(user)

    {:ok, _} =
      Accounts.change_user_password(
        user,
        valid_password(),
        %{"password" => "Rotated-2026", "password_confirmation" => "Rotated-2026"},
        except: current
      )

    assert_disconnected()
    assert Accounts.get_user_by_session_token(current)
    assert Accounts.get_user_by_session_token(elsewhere) == nil
  end

  test "a failed password change keeps every session", %{user: user} do
    elsewhere = session(user)

    {:error, _} =
      Accounts.change_user_password(user, "Wrong-pass1", %{"password" => "Rotated-2026"})

    refute_received %Phoenix.Socket.Broadcast{}
    assert Accounts.get_user_by_session_token(elsewhere)
  end

  test "setting a password from a setup link signs out all sessions" do
    {:ok, user, setup_token} =
      Accounts.register_email_only_user("setup-#{System.unique_integer([:positive])}@example.com")

    old = session(user)

    {:ok, _} = Accounts.set_password_from_setup_token(setup_token, "Brand-New-2026")
    assert_disconnected()
    assert Accounts.get_user_by_session_token(old) == nil
  end

  describe "active accounts" do
    test "new accounts are active", %{user: user} do
      assert user.is_active
    end

    test "inactive users can't sign in, and deactivating signs them out", %{user: user} do
      token = session(user)

      {:ok, _} = Accounts.set_user_active(user, false)
      assert_disconnected()
      assert Accounts.get_user_by_session_token(token) == nil
      assert Accounts.get_user_by_email_password(user.email, valid_password()) == nil

      {:ok, user} = Accounts.set_user_active(Repo.get!(User, user.id), true)
      assert Accounts.get_user_by_email_password(user.email, valid_password())
    end

    test "the admin deactivate and invalidate actions sign the user out", %{user: user} do
      token = session(user)

      assert {:ok, _} =
               AdminOps.run(
                 :invalidate_user_tokens,
                 %{email: user.email, confirm_text: "INVALIDATE"},
                 admin_fixture()
               )

      assert_disconnected()
      assert Accounts.get_user_by_session_token(token) == nil

      token = session(user)

      assert {:ok, _} =
               AdminOps.run(
                 :deactivate_user,
                 %{email: user.email, confirm_text: "DEACTIVATE"},
                 admin_fixture()
               )

      assert_disconnected()
      assert Accounts.get_user_by_session_token(token) == nil
    end
  end
end

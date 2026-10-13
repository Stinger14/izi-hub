defmodule Core.Accounts.HouseholdInvitationsTest do
  use Core.DataCase, async: true

  alias Core.{Accounts, Repo}
  alias Core.Accounts.HouseholdInvitation

  def invite_url(token), do: "https://izihub.test/invites/#{token}"

  setup do
    owner = user_fixture(%{full_name: "Olivia Owner"})
    {:ok, household} = Accounts.create_household(owner, %{"name" => "Garcia Home"})
    %{owner: owner, household: household}
  end

  defp token_from(url), do: url |> String.split("/") |> List.last()

  describe "invite_to_household/4" do
    test "stores only the token hash, emails the link and returns it", ctx do
      assert {:ok, invitation, url} =
               Accounts.invite_to_household(
                 ctx.owner,
                 ctx.household,
                 " New@Example.com ",
                 &__MODULE__.invite_url/1
               )

      assert invitation.email == "new@example.com"
      assert invitation.status == "pending"
      token = token_from(url)
      refute invitation.token_hash == token
      assert {:ok, invitation.token_hash} == Core.Accounts.UserToken.hash_token(token)

      # Delivered from a background task, so wait for it.
      assert_receive {:email, email}
      assert email.to == [{"", "new@example.com"}]
      assert email.subject =~ "Garcia Home"
      assert email.text_body =~ url
    end

    test "re-inviting refreshes the pending invitation and retires the old link", ctx do
      {:ok, first, old_url} =
        Accounts.invite_to_household(
          ctx.owner,
          ctx.household,
          "new@example.com",
          &__MODULE__.invite_url/1
        )

      {:ok, second, new_url} =
        Accounts.invite_to_household(
          ctx.owner,
          ctx.household,
          "NEW@example.com",
          &__MODULE__.invite_url/1
        )

      assert first.id == second.id
      assert {:error, :not_found} = Accounts.get_invitation_by_token(token_from(old_url))
      assert {:ok, _} = Accounts.get_invitation_by_token(token_from(new_url))
      assert Repo.aggregate(HouseholdInvitation, :count) == 1
    end

    test "rejects current members, bad emails and outsiders", ctx do
      member = user_fixture(%{email: "Member@Example.com"})
      {:ok, _} = Accounts.add_household_member(ctx.owner, ctx.household, member)

      assert {:error, :already_member} =
               Accounts.invite_to_household(
                 ctx.owner,
                 ctx.household,
                 "member@example.com",
                 &__MODULE__.invite_url/1
               )

      assert {:error, %Ecto.Changeset{} = changeset} =
               Accounts.invite_to_household(
                 ctx.owner,
                 ctx.household,
                 "not-an-email",
                 &__MODULE__.invite_url/1
               )

      assert %{email: [_]} = errors_on(changeset)

      outsider = user_fixture()

      assert {:error, :forbidden} =
               Accounts.invite_to_household(
                 outsider,
                 ctx.household,
                 "x@example.com",
                 &__MODULE__.invite_url/1
               )
    end

    test "any member can invite, not only the owner", ctx do
      member = user_fixture()
      {:ok, _} = Accounts.add_household_member(ctx.owner, ctx.household, member)

      assert {:ok, _invitation, _url} =
               Accounts.invite_to_household(
                 member,
                 ctx.household,
                 "friend@example.com",
                 &__MODULE__.invite_url/1
               )
    end
  end

  describe "accepting in the app" do
    test "an existing account sees the invitation and joins", ctx do
      invitee = user_fixture(%{email: "invitee@example.com"})

      {:ok, invitation, _url} =
        Accounts.invite_to_household(
          ctx.owner,
          ctx.household,
          "invitee@example.com",
          &__MODULE__.invite_url/1
        )

      assert [%{id: id, household: %{name: "Garcia Home"}}] =
               Accounts.list_pending_invitations_for_user(invitee)

      assert id == invitation.id
      assert {:ok, household} = Accounts.accept_invitation(invitee, invitation.id)
      assert household.id == ctx.household.id
      assert Accounts.user_household?(invitee, ctx.household.id)
      refute Accounts.user_household_owner?(invitee, ctx.household.id)
      assert Accounts.list_pending_invitations_for_user(invitee) == []
      assert Repo.get!(HouseholdInvitation, invitation.id).status == "accepted"
    end

    test "declining closes it without joining", ctx do
      invitee = user_fixture(%{email: "invitee@example.com"})

      {:ok, invitation, _url} =
        Accounts.invite_to_household(
          ctx.owner,
          ctx.household,
          "invitee@example.com",
          &__MODULE__.invite_url/1
        )

      assert {:ok, _} = Accounts.decline_invitation(invitee, invitation.id)
      refute Accounts.user_household?(invitee, ctx.household.id)
      assert Repo.get!(HouseholdInvitation, invitation.id).status == "declined"
    end

    test "another account can't accept someone else's invitation by id", ctx do
      {:ok, invitation, _url} =
        Accounts.invite_to_household(
          ctx.owner,
          ctx.household,
          "invitee@example.com",
          &__MODULE__.invite_url/1
        )

      stranger = user_fixture()
      assert {:error, :not_found} = Accounts.accept_invitation(stranger, invitation.id)
      refute Accounts.user_household?(stranger, ctx.household.id)
    end

    test "an account created after the invitation must use the link", ctx do
      {:ok, invitation, url} =
        Accounts.invite_to_household(
          ctx.owner,
          ctx.household,
          "late@example.com",
          &__MODULE__.invite_url/1
        )

      # Backdate the invitation so the account is clearly newer than it.
      invitation
      |> Ecto.Changeset.change(inserted_at: ~N[2020-01-01 00:00:00])
      |> Repo.update!()

      late = user_fixture(%{email: "late@example.com"})

      assert Accounts.list_pending_invitations_for_user(late) == []
      assert {:error, :not_found} = Accounts.accept_invitation(late, invitation.id)
      assert {:ok, _} = Accounts.accept_invitation(late, {:token, token_from(url)})
      assert Accounts.user_household?(late, ctx.household.id)
    end
  end

  describe "the link token" do
    test "expired, revoked and used links stop working", ctx do
      {:ok, invitation, url} =
        Accounts.invite_to_household(
          ctx.owner,
          ctx.household,
          "a@example.com",
          &__MODULE__.invite_url/1
        )

      token = token_from(url)

      invitation
      |> Ecto.Changeset.change(expires_at: ~U[2020-01-01 00:00:00Z])
      |> Repo.update!()

      assert {:error, :expired} = Accounts.get_invitation_by_token(token)

      {:ok, revoked, revoked_url} =
        Accounts.invite_to_household(
          ctx.owner,
          ctx.household,
          "b@example.com",
          &__MODULE__.invite_url/1
        )

      assert {:ok, _} = Accounts.revoke_invitation(ctx.owner, revoked.id)
      assert {:error, :used} = Accounts.get_invitation_by_token(token_from(revoked_url))

      user = user_fixture()
      assert {:error, :used} = Accounts.accept_invitation(user, {:token, token_from(revoked_url)})
      assert {:error, :not_found} = Accounts.get_invitation_by_token("garbage")
    end

    test "outsiders can't revoke", ctx do
      {:ok, invitation, _url} =
        Accounts.invite_to_household(
          ctx.owner,
          ctx.household,
          "a@example.com",
          &__MODULE__.invite_url/1
        )

      assert {:error, :forbidden} = Accounts.revoke_invitation(user_fixture(), invitation.id)
    end

    test "deleting the household deletes its invitations", ctx do
      {:ok, _invitation, _url} =
        Accounts.invite_to_household(
          ctx.owner,
          ctx.household,
          "a@example.com",
          &__MODULE__.invite_url/1
        )

      {:ok, _} = Accounts.delete_household(ctx.owner, ctx.household, "Garcia Home")
      assert Repo.aggregate(HouseholdInvitation, :count) == 0
    end
  end
end

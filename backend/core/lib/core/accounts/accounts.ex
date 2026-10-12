defmodule Core.Accounts do
  @moduledoc """
  The Accounts context - handles user auth and management
  """

  import Ecto.Query, warn: false
  alias Core.Repo

  alias Core.Accounts.{Household, HouseholdMember, User, UserToken, UsernameGenerator}

  @setup_password_token_ttl_seconds 86_400
  @username_generation_attempts 20

  @doc """
  Register new user
  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Registers a user using email only and returns a setup password token.
  """
  def register_email_only_user(email) when is_binary(email) do
    email
    |> String.trim()
    |> do_register_email_only_user(@username_generation_attempts)
  end

  @doc """
  Completes onboarding by setting a password from a setup token.
  """
  def set_password_from_setup_token(token, password)
      when is_binary(token) and is_binary(password) do
    with {:ok, user} <- get_user_by_token(token, "setup_password"),
         {:ok, user} <- update_user_password(user, password),
         :ok <- delete_user_token(token, "setup_password") do
      revoke_user_sessions(user)
      {:ok, user}
    else
      :error -> {:error, :invalid_or_expired_token}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
    end
  end

  @doc """
  Gets a user by email
  """
  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password
  """
  def get_user_by_email_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    # Inactive accounts get the same answer as a wrong password, so the
    # response doesn't reveal which emails have accounts.
    if User.valid_password?(user, password) and user.is_active, do: user
  end

  @doc """
  Get user by username
  """
  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username: username)
  end

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Returns total users count.
  """
  def count_users do
    Repo.aggregate(User, :count)
  end

  @doc """
  Returns active users count.
  """
  def count_active_users do
    User
    |> where([u], u.is_active == true)
    |> Repo.aggregate(:count)
  end

  @doc """
  Returns the most recent users.
  """
  def list_recent_users(limit \\ 5) do
    User
    |> order_by([u], desc: u.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets a single user.
  """
  def get_user!(id), do: Repo.get!(User, id)

  def get_user(id), do: Repo.get(User, id)

  def create_household(%User{} = owner, attrs) do
    attrs =
      attrs
      |> Map.new()
      |> Map.put_new(
        "slug",
        slugify_household_name(Map.get(attrs, "name") || Map.get(attrs, :name))
      )

    Repo.transaction(fn ->
      case %Household{} |> Household.changeset(attrs) |> Repo.insert() do
        {:ok, household} ->
          membership_attrs = %{
            "household_id" => household.id,
            "user_id" => owner.id,
            "role" => "owner",
            "status" => "active"
          }

          case %HouseholdMember{}
               |> HouseholdMember.changeset(membership_attrs)
               |> Repo.insert() do
            {:ok, _membership} ->
              household

            {:error, changeset} ->
              Repo.rollback(changeset)
          end

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  def add_household_member(
        %User{} = actor,
        %Household{} = household,
        %User{} = member,
        attrs \\ %{}
      ) do
    with :ok <- ensure_household_owner(actor, household) do
      membership_attrs =
        attrs
        |> Map.new()
        |> Map.put("household_id", household.id)
        |> Map.put("user_id", member.id)
        |> Map.put_new("role", "member")
        |> Map.put_new("status", "active")

      %HouseholdMember{}
      |> HouseholdMember.changeset(membership_attrs)
      |> Repo.insert()
      |> notify_household_change(household.id)
    end
  end

  def add_household_member_by_email(
        %User{} = actor,
        %Household{} = household,
        email,
        attrs \\ %{}
      )
      when is_binary(email) do
    email = String.trim(email)

    with %User{} = member <- get_user_by_email(email),
         {:ok, membership} <- add_household_member(actor, household, member, attrs) do
      {:ok, membership}
    else
      nil -> {:error, :user_not_found}
      {:error, _reason} = error -> error
    end
  end

  def list_households_for_user(%User{} = user) do
    Household
    |> join(:inner, [household], membership in HouseholdMember,
      on: membership.household_id == household.id
    )
    |> where(
      [_household, membership],
      membership.user_id == ^user.id and membership.status == "active"
    )
    |> where([household, _membership], household.status == "active")
    |> order_by([household, _membership], asc: household.name)
    |> preload([_household, membership], memberships: ^active_memberships_query())
    |> distinct(true)
    |> Repo.all()
  end

  def get_household_for_user!(%User{} = user, household_id) do
    Household
    |> join(:inner, [household], membership in HouseholdMember,
      on: membership.household_id == household.id
    )
    |> where(
      [household, membership],
      household.id == ^household_id and membership.user_id == ^user.id
    )
    |> where(
      [household, membership],
      household.status == "active" and membership.status == "active"
    )
    |> preload([_household, _membership], memberships: ^active_memberships_query())
    |> distinct(true)
    |> Repo.one!()
  end

  def user_household?(%User{} = user, household_id) do
    HouseholdMember
    |> where(
      [membership],
      membership.user_id == ^user.id and membership.household_id == ^household_id
    )
    |> where([membership], membership.status == "active")
    |> Repo.exists?()
  end

  def user_household_owner?(%User{} = user, household_id) do
    HouseholdMember
    |> where(
      [membership],
      membership.user_id == ^user.id and membership.household_id == ^household_id
    )
    |> where([membership], membership.status == "active" and membership.role == "owner")
    |> Repo.exists?()
  end

  # ------ Managing a household ------
  #
  # Owners rename, remove members and delete; members can leave. Every change
  # notifies the household's finance topic so open pages (and the hub) of all
  # members reload — a removed member or a deleted household drops out of
  # their scope picker immediately.

  @doc "Renames a household (owner only). The slug is kept so links stay stable."
  def rename_household(%User{} = actor, %Household{} = household, attrs) do
    with :ok <- ensure_household_owner(actor, household) do
      household
      |> Household.changeset(Map.take(Map.new(attrs), ["name", :name]))
      |> Repo.update()
      |> notify_household_change(household.id)
    end
  end

  @doc "Removes a member (owner only). The owner can't be removed."
  def remove_household_member(%User{} = actor, %Household{} = household, member_user_id) do
    with :ok <- ensure_household_owner(actor, household),
         %HouseholdMember{} = membership <- get_membership(household.id, member_user_id),
         :ok <- ensure_not_owner(membership) do
      membership |> Repo.delete() |> notify_household_change(household.id)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Leaves a household. Owners can't leave (they would orphan it): they delete
  the household instead.
  """
  def leave_household(%User{} = user, %Household{} = household) do
    case get_membership(household.id, user.id) do
      nil -> {:error, :not_found}
      %HouseholdMember{role: "owner"} -> {:error, :owner_cannot_leave}
      membership -> membership |> Repo.delete() |> notify_household_change(household.id)
    end
  end

  @doc """
  Deletes a household and, through the database's cascading foreign keys,
  every finance record it owns. Owner only, and only when `confirmation`
  matches the household's name (case and surrounding spaces ignored).
  """
  def delete_household(%User{} = actor, %Household{} = household, confirmation) do
    with :ok <- ensure_household_owner(actor, household),
         :ok <- ensure_confirmation(household, confirmation) do
      household |> Repo.delete() |> notify_household_change(household.id)
    end
  end

  defp get_membership(household_id, user_id) do
    Repo.get_by(HouseholdMember, household_id: household_id, user_id: user_id)
  end

  defp ensure_not_owner(%HouseholdMember{role: "owner"}), do: {:error, :cannot_remove_owner}
  defp ensure_not_owner(_membership), do: :ok

  defp ensure_confirmation(%Household{name: name}, confirmation) when is_binary(confirmation) do
    if normalize_confirmation(confirmation) == normalize_confirmation(name),
      do: :ok,
      else: {:error, :confirmation_mismatch}
  end

  defp ensure_confirmation(_household, _confirmation), do: {:error, :confirmation_mismatch}

  defp normalize_confirmation(value), do: value |> String.trim() |> String.downcase()

  defp notify_household_change({:ok, _} = result, household_id) do
    Core.Finance.notify_household_change(household_id)
    result
  end

  defp notify_household_change(result, _household_id), do: result

  def change_household(%Household{} = household \\ %Household{}) do
    Household.changeset(household, %{})
  end

  @doc """
  Updates user profile
  """
  def update_user_profile(user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Links (or clears) the user's GitHub username.
  """
  def update_github_username(user, attrs) do
    user
    |> User.github_username_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates the signed-in user's name and username from the settings page.
  """
  def update_account_profile(%User{} = user, attrs) do
    user
    |> User.account_profile_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Changes the signed-in user's email. Requires their current password.
  """
  def change_user_email(%User{} = user, current_password, attrs) do
    user
    |> User.email_update_changeset(attrs, current_password)
    |> Repo.update()
  end

  @doc """
  Changes the signed-in user's password. Requires their current password and
  a matching `password_confirmation`.
  """
  def change_user_password(%User{} = user, current_password, attrs, opts \\ []) do
    changeset = User.password_update_changeset(user, attrs, current_password)

    Repo.transaction(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        {user, delete_session_tokens(user, opts)}
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, {user, revoked_ids}} ->
        disconnect_sessions(revoked_ids)
        {:ok, user}

      error ->
        error
    end
  end

  # ------ Sessions ------
  #
  # A signed-in browser holds a random session token; only its SHA-256 hash is
  # stored in `user_tokens`. Deleting the row signs that browser out, and
  # `disconnect_sessions/1` drops its open LiveViews (their socket id is
  # "user_sessions:<row id>", set in the session at sign-in).

  @session_validity_in_days 60

  def session_validity_in_seconds, do: @session_validity_in_days * 24 * 60 * 60

  @doc "Issues a session token. Returns `{raw_token, token_row_id}`."
  def generate_user_session_token(%User{} = user) do
    {token, user_token} = UserToken.create_token(user, "session", session_validity_in_seconds())
    %UserToken{id: id} = Repo.insert!(user_token)
    {token, id}
  end

  @doc "The active user for a session token, or nil if it's unknown, expired or the user is inactive."
  def get_user_by_session_token(token) when is_binary(token) do
    with {:ok, query} <- UserToken.verify_token_query(token, "session"),
         %User{is_active: true} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  def get_user_by_session_token(_token), do: nil

  @doc "Signs out one session (logout)."
  def delete_user_session_token(token) when is_binary(token) do
    case UserToken.hash_token(token) do
      {:ok, hashed} ->
        {_, ids} =
          Repo.delete_all(
            from(t in UserToken,
              where: t.token_type == "session" and t.token == ^hashed,
              select: t.id
            )
          )

        disconnect_sessions(ids)
        :ok

      :error ->
        :ok
    end
  end

  def delete_user_session_token(_token), do: :ok

  @doc """
  Signs the user out of every session, or every one but the token passed as
  `except:`. Returns how many were revoked.
  """
  def revoke_user_sessions(%User{} = user, opts \\ []) do
    ids = delete_session_tokens(user, opts)
    disconnect_sessions(ids)
    length(ids)
  end

  defp delete_session_tokens(user, opts) do
    query =
      from(t in UserToken,
        where: t.user_id == ^user.id and t.token_type == "session",
        select: t.id
      )

    query =
      with token when is_binary(token) <- opts[:except],
           {:ok, hashed} <- UserToken.hash_token(token) do
        where(query, [t], t.token != ^hashed)
      else
        _ -> query
      end

    {_, ids} = Repo.delete_all(query)
    ids
  end

  defp disconnect_sessions(ids) do
    Enum.each(ids, fn id ->
      topic = session_socket_id(id)

      Phoenix.PubSub.broadcast(Core.PubSub, topic, %Phoenix.Socket.Broadcast{
        topic: topic,
        event: "disconnect",
        payload: %{}
      })
    end)
  end

  @doc "The LiveView socket id for a session, so it can be disconnected."
  def session_socket_id(token_row_id), do: "user_sessions:#{token_row_id}"

  @doc "Deactivates or reactivates a user. Deactivating signs them out everywhere."
  def set_user_active(%User{} = user, active?) when is_boolean(active?) do
    with {:ok, user} <- user |> Ecto.Changeset.change(is_active: active?) |> Repo.update() do
      unless active?, do: revoke_user_sessions(user)
      {:ok, user}
    end
  end

  @doc """
  Updates user password
  """
  def update_user_password(user, password) do
    user
    |> User.password_changeset(%{password: password})
    |> Repo.update()
  end

  @doc """
  Updates user email
  """
  def update_user_email(user, email) do
    user
    |> User.email_changeset(%{email: email})
    |> Repo.update()
  end

  @doc """
  Updates last login timestamp
  """
  def update_last_login(%User{} = user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    user
    |> Ecto.Changeset.change(%{last_login_at: now})
    |> Repo.update()
  end

  @doc """
  Verifies user email
  """
  def verify_user_email(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    user
    |> Ecto.Changeset.change(%{
      email_verified: true,
      email_verified_at: now
    })
    |> Repo.update()
  end

  @doc """
  Deletes a user
  """
  def delete_user(user) do
    Repo.delete(user)
  end

  @doc """
  Lists users with pagination
  """
  def list_users_paginated(page \\ 1, per_page \\ 20) do
    offset = (page - 1) * per_page

    users =
      User
      |> limit(^per_page)
      |> offset(^offset)
      |> order_by(desc: :inserted_at)
      |> Repo.all()

    total_count = Repo.aggregate(User, :count)

    %{
      users: users,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: ceil(total_count / per_page)
    }
  end

  @doc """
  Generates an access token for user
  """
  def generate_access_token(user) do
    # 1 hour
    {token, user_token} = UserToken.create_token(user, "access", 3600)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Generates a refrest token for user
  """
  def generate_refresh_token(user) do
    # 7 days
    {token, user_token} = UserToken.create_token(user, "refresh", 604_800)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Generates a password reset token
  """
  def generate_password_reset_token(user) do
    # 1 hour
    {token, user_token} = UserToken.create_token(user, "reset_password", 3600)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Generates an email verification token
  """
  def generate_email_verification_token(user) do
    # 24 hours
    {token, user_token} = UserToken.create_token(user, "verify_email", 86400)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Generates a setup password token.
  """
  def generate_setup_password_token(user) do
    from(t in UserToken,
      where: t.user_id == ^user.id and t.token_type == "setup_password"
    )
    |> Repo.delete_all()

    {token, user_token} =
      UserToken.create_token(user, "setup_password", @setup_password_token_ttl_seconds)

    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets user by token
  """
  def get_user_by_token(token, token_type) do
    with {:ok, query} <- UserToken.verify_token_query(token, token_type),
         %User{} = user <- Repo.one(query) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  @doc """
  Deletes user token
  """
  def delete_user_token(token, token_type) do
    token_query =
      case Base.url_decode64(token, padding: false) do
        {:ok, decoded_token} ->
          hashed_token = :crypto.hash(:sha256, decoded_token) |> Base.encode64()
          from(t in UserToken, where: t.token == ^hashed_token and t.token_type == ^token_type)

        :error ->
          from(t in UserToken, where: t.token == ^token and t.token_type == ^token_type)
      end

    token_query
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Deletes all tokens for a user
  """
  def delete_user_tokens(%User{} = user) do
    {count, rows} =
      Repo.delete_all(
        from(t in UserToken, where: t.user_id == ^user.id, select: {t.id, t.token_type})
      )

    disconnect_sessions(for {id, "session"} <- rows, do: id)
    {count, nil}
  end

  @doc """
  Deletes expired tokens (to be run as a background job)
  """
  def delete_expired_tokens do
    from(t in UserToken, where: t.expires_at < ^NaiveDateTime.utc_now())
    |> Repo.delete_all()
  end

  defp do_register_email_only_user(_email, 0), do: {:error, :username_generation_failed}

  defp do_register_email_only_user(email, attempts_left) do
    attrs = %{
      "email" => email,
      "username" => UsernameGenerator.generate(),
      "password" => generate_bootstrap_password()
    }

    case register_user(attrs) do
      {:ok, user} ->
        {:ok, user, generate_setup_password_token(user)}

      {:error, %Ecto.Changeset{} = changeset} ->
        if username_collision?(changeset) do
          do_register_email_only_user(email, attempts_left - 1)
        else
          {:error, changeset}
        end
    end
  end

  defp username_collision?(changeset) do
    Enum.any?(changeset.errors, fn
      {:username, {"has already been taken", _opts}} -> true
      _ -> false
    end)
  end

  defp generate_bootstrap_password do
    "TmpA1a-" <> Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)
  end

  defp ensure_household_owner(%User{} = user, %Household{} = household) do
    if user_household_owner?(user, household.id), do: :ok, else: {:error, :forbidden}
  end

  defp active_memberships_query do
    from membership in HouseholdMember,
      where: membership.status == "active",
      order_by: [asc: membership.role, asc: membership.inserted_at],
      preload: [:user]
  end

  defp slugify_household_name(nil), do: nil

  defp slugify_household_name(name) do
    name
    |> to_string()
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end
end

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
    if User.valid_password?(user, password), do: user
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
    with :ok <- ensure_household_member(actor, household) do
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
    Repo.delete_all(UserToken, user_id: user.id)
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

  defp ensure_household_member(%User{} = user, %Household{} = household) do
    if user_household?(user, household.id), do: :ok, else: {:error, :forbidden}
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

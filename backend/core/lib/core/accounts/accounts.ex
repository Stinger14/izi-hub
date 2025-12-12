defmodule Core.Accounts do
  @moduledoc """
  The Accounts context - handles user auth and management
  """

  import Ecto.Query, warn: false
  alias Core.Repo

  alias Core.Accounts.{User, UserToken}

  @doc """
  Register new user
  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
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
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

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
    user
    |> Ecto.Changeset.change(%{last_login_at: NaiveDateTime.utc_now()})
    |> Repo.update()
  end

  @doc """
  Verifies user email
  """
  def verify_user_email(user) do
    user
    |> Ecto.Changeset.change(%{
      email_verified: true,
      email_verified_at: NaiveDateTime.utc_now()
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
    from(t in UserToken, where: t.token == ^token and t.token_type == ^token_type)
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
end

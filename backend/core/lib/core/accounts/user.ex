defmodule Core.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :hashed_password, :string
    field :password, :string, virtual: true, redact: true
    field :username, :string
    field :full_name, :string
    field :avatar_url, :string
    field :role, :string, default: "user"
    field :is_active, :boolean, default: false
    field :email_verified, :boolean, default: false
    field :email_verified_at, :naive_datetime
    field :last_login_at, :naive_datetime

    has_many :user_tokens, Core.Accounts.UserToken
    has_many :projects, Core.Portfolio.Project
    has_many :posts, Core.Blog.Post
    has_many :transactions, Core.Finance.Transaction
    has_many :categories, Core.Finance.Category
    has_many :budgets, Core.Finance.Budget
    has_many :notifications, Core.Notifications.Notification
    has_many :office_projects, Core.Office.Project
    has_many :office_work_items, Core.Office.WorkItem
    has_many :office_timeline_entries, Core.Office.TimelineEntry

    timestamps()
  end

  @doc """
  Changeset for user registration.
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :username, :full_name])
    |> validate_required([:email, :password, :username])
    |> validate_email()
    |> validate_username()
    |> validate_password()
    |> hash_password()
  end

  @doc """
  Changeset for user profile updates
  """
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :full_name, :avatar_url])
    |> validate_required([:username])
    |> validate_username()
    |> validate_format(:avatar_url, ~r/^https?:\/\//, message: "must be a valid URL")
  end

  @doc """
  Changeset for password updates
  """
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_password()
    |> hash_password()
  end

  @doc """
  Changeset for email updates
  """
  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_required([:email])
    |> validate_email()
    |> put_change(:email_verified, false)
    |> put_change(:email_verified_at, nil)
  end

  # Validation helpers
  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Core.Repo)
    |> unique_constraint(:email)
  end

  defp validate_username(changeset) do
    changeset
    |> validate_length(:username, min: 3, max: 100)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_-]+$/,
      message: "can only contain letters, numbers, underscores, and hyphens"
    )
    |> unsafe_validate_unique(:username, Core.Repo)
    |> unique_constraint(:username)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> validate_format(:password, ~r/[a-z]/,
      message: "must contain at least one lowercase letter"
    )
    |> validate_format(:password, ~r/[A-Z]/,
      message: "must contain at least one uppercase letter"
    )
    |> validate_format(:password, ~r/[0-9]/, message: "must contain at least one digit")
  end

  defp hash_password(changeset) do
    password = get_change(changeset, :password)

    if password && changeset.valid? do
      changeset
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Verifies the password against the hashed password
  """
  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end

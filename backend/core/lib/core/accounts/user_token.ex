defmodule Core.Accounts.UserToken do
  @moduledoc """
  Tokens for sessions, password setup/reset, email verification and the API.

  Context: only the SHA-256 hash is stored; the raw token goes to the browser
  or the link. `Core.Accounts` creates, looks up and deletes them.

  ## Example

      {raw, token} = UserToken.create_token(user, "session", 3600)
      {:ok, query} = UserToken.verify_token_query(raw, "session")
  """

  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @token_types [
    "access",
    "refresh",
    "reset_password",
    "verify_email",
    "setup_password",
    "session"
  ]

  @hash_algorithm :sha256
  @rand_size 32

  schema "user_tokens" do
    field :token, :string
    field :token_type, :string
    field :expires_at, :naive_datetime

    belongs_to :user, Core.Accounts.User

    timestamps()
  end

  @doc "Builds a token of `token_type`: returns `{raw_token, %UserToken{}}` (insert the struct)."
  def create_token(user, token_type, expires_in_seconds \\ 3600) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token) |> Base.encode64()

    expires_at =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(expires_in_seconds, :second)
      |> NaiveDateTime.truncate(:second)

    {Base.url_encode64(token, padding: false),
     %__MODULE__{
       token: hashed_token,
       token_type: token_type,
       expires_at: expires_at,
       user_id: user.id
     }}
  end

  @doc "Query for the user of an unexpired token of this type. `{:ok, query}` or `:error`."
  def verify_token_query(token, token_type) do
    with {:ok, decoded_token} <- Base.url_decode64(token, padding: false) do
      query =
        from token in by_token_type_query(decoded_token, token_type),
          join: user in assoc(token, :user),
          where: token.expires_at > ^NaiveDateTime.utc_now(),
          select: user

      {:ok, query}
    else
      :error -> :error
    end
  end

  defp by_token_type_query(decoded_token, token_type) do
    hashed_token = :crypto.hash(@hash_algorithm, decoded_token) |> Base.encode64()

    from __MODULE__,
      where: [token: ^hashed_token, token_type: ^token_type]
  end

  @doc "Hashes a raw token the way it's stored. `{:ok, hash}` or `:error`."
  def hash_token(token) when is_binary(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded} -> {:ok, :crypto.hash(@hash_algorithm, decoded) |> Base.encode64()}
      :error -> :error
    end
  end

  @doc "Generic token changeset."
  def changeset(token, attrs) do
    token
    |> cast(attrs, [:token, :token_type, :expires_at, :user_id])
    |> validate_required([:token, :token_type, :expires_at, :user_id])
    |> validate_inclusion(:token_type, @token_types)
    |> foreign_key_constraint(:user_id)
  end
end

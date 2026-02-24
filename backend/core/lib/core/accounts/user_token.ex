defmodule Core.Accounts.UserToken do
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @token_types ["access", "refresh", "reset_password", "verify_email", "setup_password"]

  @hash_algorithm :sha256
  @rand_size 32

  schema "user_tokens" do
    field :token, :string
    field :token_type, :string
    field :expires_at, :naive_datetime

    belongs_to :user, Core.Accounts.User

    timestamps()
  end

  @doc """
  Generates a token
  """
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

  @doc """
    Checks if a token is valid
  """
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

  @doc """
  Return token struct to be inserted in db
  """
  def changeset(token, attrs) do
    token
    |> cast(attrs, [:token, :token_type, :expires_at, :user_id])
    |> validate_required([:token, :token_type, :expires_at, :user_id])
    |> validate_inclusion(:token_type, @token_types)
    |> foreign_key_constraint(:user_id)
  end
end

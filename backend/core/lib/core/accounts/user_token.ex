defmodule Core.Accounts.UserToken do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_tokens" do
    field :token, :string
    field :token_type, :string
    field :expires_at, :naive_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_token, attrs) do
    user_token
    |> cast(attrs, [:token, :token_type, :expires_at])
    |> validate_required([:token, :token_type, :expires_at])
  end
end

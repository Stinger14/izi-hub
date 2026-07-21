defmodule Core.Finance.IngestionToken do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "finance_ingestion_tokens" do
    field(:token, :string)
    field(:revoked_at, :utc_datetime)

    belongs_to(:user, Core.Accounts.User)

    timestamps()
  end

  @doc false
  def changeset(ingestion_token, attrs) do
    ingestion_token
    |> cast(attrs, [:revoked_at])
    |> validate_required([:user_id, :token])
    |> validate_length(:token, min: 1, max: 255)
    |> unique_constraint(:token)
    |> foreign_key_constraint(:user_id)
  end
end

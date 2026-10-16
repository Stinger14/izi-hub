defmodule Core.Finance.IngestionToken do
  @moduledoc """
  An API token the email ingestion service uses to post a user's bank emails.

  Context: Created and revoked through `Core.Finance`; `user_for_ingestion_token/1`
  is the service's auth check.
  """

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

  @doc "Requires the token and user."
  def changeset(ingestion_token, attrs) do
    ingestion_token
    |> cast(attrs, [:revoked_at])
    |> validate_required([:user_id, :token])
    |> validate_length(:token, min: 1, max: 255)
    |> unique_constraint(:token)
    |> foreign_key_constraint(:user_id)
  end
end

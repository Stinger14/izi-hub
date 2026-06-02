defmodule Core.Finance.EmailIngestionAttempt do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "finance_email_ingestions" do
    field :provider, :string
    field :message_id, :string
    field :sender, :string
    field :subject, :string
    field :received_at, :utc_datetime
    field :parser_name, :string
    field :status, :string
    field :error_reason, :string
    field :body_snippet, :string

    belongs_to :user, Core.Accounts.User
    belongs_to :transaction, Core.Finance.Transaction

    timestamps()
  end

  @statuses [
    "created",
    "duplicate",
    "unsupported_email",
    "unparseable_email",
    "invalid_transaction"
  ]

  @doc false
  def changeset(attempt, attrs) do
    attempt
    |> cast(attrs, [
      :provider,
      :message_id,
      :sender,
      :subject,
      :received_at,
      :parser_name,
      :status,
      :error_reason,
      :body_snippet,
      :transaction_id
    ])
    |> validate_required([:user_id, :status])
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:provider, max: 120)
    |> validate_length(:message_id, max: 255)
    |> validate_length(:sender, max: 255)
    |> validate_length(:subject, max: 500)
    |> validate_length(:parser_name, max: 255)
    |> validate_length(:error_reason, max: 500)
    |> validate_length(:body_snippet, max: 1000)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:transaction_id)
  end
end

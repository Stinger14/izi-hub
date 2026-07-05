defmodule Core.Finance.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "transactions" do
    field :amount, :decimal
    field :type, :string
    field :source, :string, default: "manual"
    field :status, :string, default: "confirmed"
    field :description, :string
    field :merchant, :string
    field :external_id, :string
    field :confidence, :float
    field :raw_description, :string
    field :review_reason, :string
    field :transaction_date, :date
    field :payment_method, :string
    field :tags, {:array, :string}, default: []
    field :receipt_url, :string
    field :notes, :string

    belongs_to :account, Core.Finance.Account
    belongs_to :user, Core.Accounts.User
    belongs_to :household, Core.Accounts.Household
    belongs_to :category, Core.Finance.Category
    has_many :debt_payments, Core.Finance.DebtPayment

    timestamps()
  end

  @transaction_types ["income", "expense"]
  @sources ["manual", "email", "bank_import"]
  @statuses ["confirmed", "pending_review", "ignored"]
  @payment_methods ["cash", "card", "bank_transfer", "digital_wallet", "check", "other"]

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :amount,
      :type,
      :source,
      :status,
      :description,
      :merchant,
      :external_id,
      :confidence,
      :raw_description,
      :review_reason,
      :transaction_date,
      :payment_method,
      :tags,
      :receipt_url,
      :notes,
      :account_id,
      :category_id,
      :user_id,
      :household_id
    ])
    |> normalize_blank_fields([
      :payment_method,
      :merchant,
      :external_id,
      :raw_description,
      :review_reason
    ])
    |> validate_required([:amount, :type, :transaction_date])
    |> validate_inclusion(:type, @transaction_types)
    |> validate_inclusion(:source, @sources)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:payment_method, @payment_methods)
    |> validate_owner_scope()
    |> validate_number(:amount, greater_than: 0)
    |> validate_number(:confidence, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> validate_length(:description, max: 500)
    |> validate_length(:merchant, max: 255)
    |> validate_length(:external_id, max: 255)
    |> validate_length(:raw_description, max: 1000)
    |> validate_length(:notes, max: 1000)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:household_id)
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:category_id)
    |> external_id_scope_constraint()
  end

  defp normalize_blank_fields(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, acc ->
      update_change(acc, field, fn
        "" -> nil
        value -> value
      end)
    end)
  end

  defp validate_owner_scope(changeset) do
    user_id = get_field(changeset, :user_id)
    household_id = get_field(changeset, :household_id)

    if is_nil(user_id) == is_nil(household_id) do
      add_error(changeset, :base, "must belong to exactly one owner scope")
    else
      changeset
    end
  end

  defp external_id_scope_constraint(changeset) do
    if get_field(changeset, :household_id) do
      unique_constraint(changeset, :external_id,
        name: :transactions_household_id_external_id_index
      )
    else
      unique_constraint(changeset, :external_id, name: :transactions_user_id_external_id_index)
    end
  end
end

defmodule Core.Finance.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "transactions" do
    field :amount, :decimal
    field :type, :string
    field :description, :string
    field :transaction_date, :date
    field :payment_method, :string
    field :tags, {:array, :string}, default: []
    field :receipt_url, :string
    field :notes, :string

    belongs_to :user, Core.Accounts.User
    belongs_to :category, Core.Finance.Category

    timestamps()
  end

  @transaction_types ["income", "expense"]
  @payment_methods ["cash", "card", "bank_transfer", "digital_wallet", "check", "other"]

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :amount,
      :type,
      :description,
      :transaction_date,
      :payment_method,
      :tags,
      :receipt_url,
      :notes,
      :user_id,
      :category_id
    ])
    |> validate_required([:amount, :type, :user_id, :transaction_date])
    |> validate_inclusion(:type, @transaction_types)
    |> validate_inclusion(:payment_method, @payment_methods)
    |> validate_number(:amount, greater_than: 0)
    |> validate_length(:description, max: 500)
    |> validate_length(:notes, max: 1000)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:category_id)
  end
end

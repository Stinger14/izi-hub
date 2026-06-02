defmodule Core.Finance.DebtPayment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "debt_payments" do
    field :amount, :decimal
    field :payment_date, :date
    field :kind, :string, default: "extra"
    field :notes, :string

    belongs_to :user, Core.Accounts.User
    belongs_to :debt, Core.Finance.Debt
    belongs_to :transaction, Core.Finance.Transaction

    timestamps()
  end

  @kinds ["minimum", "extra", "settlement", "adjustment"]

  @doc false
  def changeset(payment, attrs) do
    payment
    |> cast(attrs, [:amount, :payment_date, :kind, :notes, :transaction_id])
    |> validate_required([:amount, :payment_date, :kind, :user_id, :debt_id])
    |> validate_inclusion(:kind, @kinds)
    |> validate_number(:amount, greater_than: 0)
    |> validate_length(:notes, max: 1000)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:debt_id)
    |> foreign_key_constraint(:transaction_id)
  end
end

defmodule Core.Finance.Debt do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "debts" do
    field :name, :string
    field :kind, :string, default: "other"
    field :provider, :string
    field :principal_balance, :decimal
    field :current_balance, :decimal
    field :apr, :decimal
    field :minimum_payment, :decimal
    field :due_day, :integer
    field :opened_on, :date
    field :payoff_goal_date, :date
    field :status, :string, default: "active"

    belongs_to :user, Core.Accounts.User
    belongs_to :household, Core.Accounts.Household
    has_many :payments, Core.Finance.DebtPayment

    timestamps()
  end

  @kinds ["credit_card", "loan", "student_loan", "mortgage", "medical", "personal", "other"]
  @statuses ["active", "paid_off", "archived"]

  @doc false
  def changeset(debt, attrs) do
    debt
    |> cast(attrs, [
      :name,
      :kind,
      :provider,
      :principal_balance,
      :current_balance,
      :apr,
      :minimum_payment,
      :due_day,
      :opened_on,
      :payoff_goal_date,
      :status,
      :user_id,
      :household_id
    ])
    |> validate_required([:name, :kind, :current_balance, :minimum_payment])
    |> validate_length(:name, min: 1, max: 120)
    |> validate_length(:provider, max: 120)
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:status, @statuses)
    |> validate_owner_scope()
    |> validate_number(:current_balance, greater_than_or_equal_to: 0)
    |> validate_number(:principal_balance, greater_than_or_equal_to: 0)
    |> validate_number(:minimum_payment, greater_than_or_equal_to: 0)
    |> validate_number(:apr, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:due_day, greater_than_or_equal_to: 1, less_than_or_equal_to: 31)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:household_id)
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
end

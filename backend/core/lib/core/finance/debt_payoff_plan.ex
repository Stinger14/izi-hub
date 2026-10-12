defmodule Core.Finance.DebtPayoffPlan do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "debt_payoff_plans" do
    field :name, :string
    field :strategy, :string
    field :monthly_amount, :decimal
    field :starts_on, :date
    field :target_payoff_date, :date
    field :status, :string, default: "active"
    field :snapshot, :map, default: %{}

    belongs_to :user, Core.Accounts.User
    belongs_to :household, Core.Accounts.Household

    timestamps()
  end

  @strategies ["snowball", "avalanche"]
  @statuses ["active", "archived"]

  @doc false
  def changeset(plan, attrs) do
    plan
    |> cast(attrs, [
      :name,
      :strategy,
      :monthly_amount,
      :starts_on,
      :target_payoff_date,
      :status,
      :snapshot,
      :user_id,
      :household_id
    ])
    |> validate_required([
      :name,
      :strategy,
      :monthly_amount,
      :starts_on,
      :status,
      :snapshot
    ])
    |> validate_length(:name, min: 1, max: 140)
    |> validate_inclusion(:strategy, @strategies)
    |> validate_inclusion(:status, @statuses)
    |> validate_owner_scope()
    |> validate_number(:monthly_amount, greater_than_or_equal_to: 0)
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

defmodule Core.Finance.SavingsGoal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "savings_goals" do
    field :name, :string
    field :target_amount, :decimal
    field :saved_amount, :decimal, default: Decimal.new("0")
    field :currency, :string, default: "DOP"
    field :target_date, :date
    field :status, :string, default: "active"
    field :notes, :string

    belongs_to :user, Core.Accounts.User
    belongs_to :household, Core.Accounts.Household

    timestamps()
  end

  @statuses ["active", "achieved", "archived"]

  def changeset(goal, attrs) do
    goal
    |> cast(attrs, [
      :name,
      :target_amount,
      :saved_amount,
      :currency,
      :target_date,
      :status,
      :notes,
      :user_id,
      :household_id
    ])
    |> normalize_blank_fields([:target_date, :notes])
    |> validate_required([:name, :target_amount, :currency, :status])
    |> validate_length(:name, min: 1, max: 120)
    |> validate_length(:currency, is: 3)
    |> update_change(:currency, &normalize_currency/1)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:target_amount, greater_than: 0)
    |> validate_number(:saved_amount, greater_than_or_equal_to: 0)
    |> validate_length(:notes, max: 1000)
    |> validate_owner_scope()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:household_id)
  end

  defp normalize_blank_fields(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, acc ->
      update_change(acc, field, fn
        "" -> nil
        value -> value
      end)
    end)
  end

  defp normalize_currency(nil), do: nil
  defp normalize_currency(currency), do: currency |> String.trim() |> String.upcase()

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

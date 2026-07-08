defmodule Core.Finance.Budget do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "budgets" do
    field :name, :string
    field :amount, :decimal
    field :currency, :string, default: "DOP"
    field :period, :string
    field :start_date, :date
    field :end_date, :date
    field :alert_threshold, :integer, default: 80
    field :is_active, :boolean, default: true

    belongs_to :user, Core.Accounts.User
    belongs_to :household, Core.Accounts.Household
    belongs_to :category, Core.Finance.Category

    timestamps()
  end

  @periods ["daily", "weekly", "monthly", "quarterly", "yearly", "custom"]

  @doc false
  def changeset(budget, attrs) do
    budget
    |> cast(attrs, [
      :name,
      :amount,
      :currency,
      :period,
      :start_date,
      :end_date,
      :alert_threshold,
      :is_active,
      :category_id,
      :user_id,
      :household_id
    ])
    |> validate_required([:name, :amount, :currency, :period, :start_date])
    |> validate_number(:amount, greater_than: 0)
    |> validate_length(:currency, is: 3)
    |> update_change(:currency, &normalize_currency/1)
    |> validate_inclusion(:period, @periods)
    |> validate_number(:alert_threshold, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_owner_scope()
    |> validate_date_range()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:household_id)
    |> foreign_key_constraint(:category_id)
  end

  defp validate_date_range(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    if start_date && end_date && Date.compare(start_date, end_date) == :gt do
      add_error(changeset, :end_date, "must be after start date")
    else
      changeset
    end
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

  defp normalize_currency(nil), do: nil
  defp normalize_currency(currency), do: currency |> String.trim() |> String.upcase()
end

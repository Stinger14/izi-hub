defmodule Core.Finance.Budget do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "budgets" do
    field :name, :string
    field :amount, :decimal
    field :period, :string
    field :start_date, :date
    field :end_date, :date
    field :alert_threshold, :integer, default: 80
    field :is_active, :boolean, default: true

    belongs_to :user, Core.Accounts.User
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
      :period,
      :start_date,
      :end_date,
      :alert_threshold,
      :is_active,
      :category_id
    ])
    |> validate_required([:name, :amount, :period, :start_date, :user_id])
    |> validate_number(:amount, greater_than: 0)
    |> validate_inclusion(:period, @periods)
    |> validate_number(:alert_threshold, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_date_range()
    |> foreign_key_constraint(:user_id)
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
end

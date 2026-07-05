defmodule Core.Finance.Account do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "finance_accounts" do
    field :name, :string
    field :institution, :string
    field :kind, :string
    field :currency, :string, default: "USD"
    field :current_balance, :decimal, default: Decimal.new("0")
    field :available_balance, :decimal
    field :status, :string, default: "active"
    field :last_synced_at, :utc_datetime_usec
    field :notes, :string

    belongs_to :user, Core.Accounts.User
    belongs_to :household, Core.Accounts.Household
    has_many :transactions, Core.Finance.Transaction

    timestamps()
  end

  @kinds ["checking", "savings", "cash", "credit_card", "investment", "loan", "other"]
  @statuses ["active", "archived"]

  def changeset(account, attrs) do
    account
    |> cast(attrs, [
      :name,
      :institution,
      :kind,
      :currency,
      :current_balance,
      :available_balance,
      :status,
      :last_synced_at,
      :notes,
      :user_id,
      :household_id
    ])
    |> normalize_blank_fields([:institution, :available_balance, :notes])
    |> validate_required([:name, :kind, :currency, :current_balance, :status])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_length(:institution, max: 120)
    |> validate_length(:currency, is: 3)
    |> update_change(:currency, &normalize_currency/1)
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:notes, max: 1000)
    |> validate_owner_scope()
    |> unique_scope_constraint()
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

  defp unique_scope_constraint(changeset) do
    if get_field(changeset, :household_id) do
      unique_constraint(changeset, [:household_id, :name],
        name: :finance_accounts_household_id_name_index
      )
    else
      unique_constraint(changeset, [:user_id, :name], name: :finance_accounts_user_id_name_index)
    end
  end
end

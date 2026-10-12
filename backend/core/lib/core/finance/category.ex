defmodule Core.Finance.Category do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "categories" do
    field :name, :string
    field :type, :string
    field :color, :string
    field :icon, :string
    field :description, :string

    belongs_to :user, Core.Accounts.User
    belongs_to :household, Core.Accounts.Household
    has_many :budgets, Core.Finance.Budget
    has_many :transactions, Core.Finance.Transaction

    timestamps()
  end

  @category_types ["income", "expense"]

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :type, :color, :icon, :description, :user_id, :household_id])
    |> validate_required([:name, :type])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_inclusion(:type, @category_types)
    |> validate_format(:color, ~r/^#[0-9A-Fa-f]{6}$/, message: "must be a valid hex color")
    |> validate_owner_scope()
    |> unique_scope_constraint()
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

  defp unique_scope_constraint(changeset) do
    if get_field(changeset, :household_id) do
      unique_constraint(changeset, [:household_id, :name, :type],
        name: :categories_household_id_name_type_index
      )
    else
      unique_constraint(changeset, [:user_id, :name, :type])
    end
  end
end

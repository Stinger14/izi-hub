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
    has_many :budgets, Core.Finance.Budget
    has_many :transactions, Core.Finance.Transaction

    timestamps()
  end

  @category_types ["income", "expense"]

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :type, :color, :icon, :description])
    |> validate_required([:name, :type, :user_id])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_inclusion(:type, @category_types)
    |> validate_format(:color, ~r/^#[0-9A-Fa-f]{6}$/, message: "must be a valid hex color")
    |> unique_constraint([:user_id, :name, :type])
    |> foreign_key_constraint(:user_id)
  end
end

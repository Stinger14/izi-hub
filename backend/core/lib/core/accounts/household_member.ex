defmodule Core.Accounts.HouseholdMember do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "household_members" do
    field :role, :string, default: "member"
    field :status, :string, default: "active"

    belongs_to :household, Core.Accounts.Household
    belongs_to :user, Core.Accounts.User

    timestamps()
  end

  @roles ["owner", "member"]
  @statuses ["active", "inactive"]

  def changeset(household_member, attrs) do
    household_member
    |> cast(attrs, [:role, :status, :household_id, :user_id])
    |> validate_required([:role, :status, :household_id, :user_id])
    |> validate_inclusion(:role, @roles)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:household_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:household_id, :user_id])
  end
end

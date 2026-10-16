defmodule Core.Accounts.HouseholdMember do
  @moduledoc """
  A user's membership in a household, with a role (owner or member).

  Context: rows are created by `Core.Accounts` (household creation, accepted
  invitations) and deleted when someone leaves or is removed. One row per
  household and user.
  """

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

  @doc "Validates role and status for a membership."
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

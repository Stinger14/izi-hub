defmodule Core.Accounts.Household do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "households" do
    field :name, :string
    field :slug, :string
    field :status, :string, default: "active"

    has_many :memberships, Core.Accounts.HouseholdMember
    many_to_many :users, Core.Accounts.User, join_through: Core.Accounts.HouseholdMember

    timestamps()
  end

  @statuses ["active", "archived"]

  def changeset(household, attrs) do
    household
    |> cast(attrs, [:name, :slug, :status])
    |> validate_required([:name, :status])
    |> validate_length(:name, min: 2, max: 160)
    |> validate_length(:slug, max: 160)
    |> validate_inclusion(:status, @statuses)
    |> update_change(:slug, &normalize_slug/1)
    |> unsafe_validate_unique(:slug, Core.Repo)
    |> unique_constraint(:slug)
  end

  defp normalize_slug(nil), do: nil
  defp normalize_slug(""), do: nil

  defp normalize_slug(slug) do
    slug
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end
end

defmodule Core.Office.Project do
  @moduledoc """
  A user's project in IziOffice, holding tasks and a timeline.

  Context: each user has a default project that can't be archived or deleted.
  The slug comes from the name at creation and never changes after.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ["active", "archived"]

  schema "office_projects" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :status, :string, default: "active"

    belongs_to :user, Core.Accounts.User

    has_many :work_items, Core.Office.WorkItem
    has_many :timeline_entries, Core.Office.TimelineEntry

    timestamps()
  end

  @doc "Valid statuses: active or archived."
  def statuses, do: @statuses

  @doc """
  Validates name, description and status and slugifies the name; renames go through
  `Core.Office.rename_project/3` so the slug stays.
  """
  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :slug, :description, :status])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_length(:description, max: 1000)
    |> validate_inclusion(:status, @statuses)
    |> generate_slug()
    |> validate_required([:slug])
    |> unique_constraint(:slug, name: :office_projects_user_id_slug_index)
    |> foreign_key_constraint(:user_id)
  end

  defp generate_slug(changeset) do
    source = get_change(changeset, :slug) || get_change(changeset, :name)

    if is_binary(source) do
      slug =
        source
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9\s-]/, "")
        |> String.replace(~r/\s+/, "-")
        |> String.trim("-")

      put_change(changeset, :slug, slug)
    else
      changeset
    end
  end
end

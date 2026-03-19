defmodule Core.Office.TimelineEntry do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @kinds ["milestone", "deadline", "release", "note"]

  schema "office_timeline_entries" do
    field :title, :string
    field :description, :string
    field :kind, :string, default: "milestone"
    field :starts_at, :naive_datetime
    field :ends_at, :naive_datetime

    belongs_to :user, Core.Accounts.User
    belongs_to :work_item, Core.Office.WorkItem
    belongs_to :project, Core.Office.Project

    timestamps()
  end

  @doc false
  def changeset(timeline_entry, attrs) do
    timeline_entry
    |> cast(attrs, [:title, :description, :kind, :starts_at, :ends_at, :work_item_id])
    |> validate_required([:title, :kind, :starts_at])
    |> validate_length(:title, min: 1, max: 140)
    |> validate_length(:description, max: 1000)
    |> validate_inclusion(:kind, @kinds)
    |> validate_ends_at()
    |> foreign_key_constraint(:work_item_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:project_id)
  end

  defp validate_ends_at(changeset) do
    starts_at = get_field(changeset, :starts_at)
    ends_at = get_field(changeset, :ends_at)

    if is_struct(starts_at, NaiveDateTime) and is_struct(ends_at, NaiveDateTime) do
      if NaiveDateTime.compare(ends_at, starts_at) == :lt do
        add_error(changeset, :ends_at, "must be after the start")
      else
        changeset
      end
    else
      changeset
    end
  end
end

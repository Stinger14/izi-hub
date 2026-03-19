defmodule Core.Office.WorkItem do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ["queue", "wip", "qa", "release"]
  @priorities ["low", "medium", "high"]
  @allowed_transitions %{
    "queue" => ["wip"],
    "wip" => ["qa"],
    "qa" => ["wip", "release"],
    "release" => []
  }

  schema "office_work_items" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "queue"
    field :priority, :string, default: "medium"
    field :scheduled_for, :date
    field :due_at, :naive_datetime
    field :sequence, :integer, default: 0

    belongs_to :user, Core.Accounts.User
    belongs_to :project, Core.Office.Project

    has_many :transitions, Core.Office.WorkItemTransition
    has_many :timeline_entries, Core.Office.TimelineEntry

    timestamps()
  end

  def statuses, do: @statuses
  def priorities, do: @priorities

  def valid_transition?(from_status, to_status) do
    to_status in Map.get(@allowed_transitions, from_status, [])
  end

  @doc false
  def planner_changeset(work_item, attrs) do
    work_item
    |> cast(attrs, [:title, :description, :priority, :scheduled_for, :due_at])
    |> validate_required([:title])
    |> validate_length(:title, min: 1, max: 140)
    |> validate_length(:description, max: 1000)
    |> validate_inclusion(:priority, @priorities)
    |> validate_due_at_after_schedule()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:project_id)
  end

  @doc false
  def transition_changeset(work_item, attrs) do
    work_item
    |> cast(attrs, [:status, :sequence])
    |> validate_required([:status, :sequence])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:sequence, greater_than: 0)
  end

  defp validate_due_at_after_schedule(changeset) do
    scheduled_for = get_field(changeset, :scheduled_for)
    due_at = get_field(changeset, :due_at)

    if is_struct(scheduled_for, Date) and is_struct(due_at, NaiveDateTime) do
      if Date.compare(NaiveDateTime.to_date(due_at), scheduled_for) == :lt do
        add_error(changeset, :due_at, "must be on or after the scheduled date")
      else
        changeset
      end
    else
      changeset
    end
  end
end

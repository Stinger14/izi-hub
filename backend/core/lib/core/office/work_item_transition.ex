defmodule Core.Office.WorkItemTransition do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses Core.Office.WorkItem.statuses()

  schema "office_work_item_transitions" do
    field :from_status, :string
    field :to_status, :string

    belongs_to :work_item, Core.Office.WorkItem
    belongs_to :moved_by, Core.Accounts.User

    timestamps(updated_at: false)
  end

  @doc false
  def create_changeset(transition, attrs, work_item_id, moved_by_id) do
    transition
    |> cast(attrs, [:from_status, :to_status])
    |> validate_required([:from_status, :to_status])
    |> validate_inclusion(:from_status, @statuses)
    |> validate_inclusion(:to_status, @statuses)
    |> put_change(:work_item_id, work_item_id)
    |> put_change(:moved_by_id, moved_by_id)
    |> foreign_key_constraint(:work_item_id)
    |> foreign_key_constraint(:moved_by_id)
  end
end

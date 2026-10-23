defmodule Core.Studio.Draft do
  @moduledoc """
  An AI result (hooks, script, caption…) saved against a piece.

  Context: `body` is the Polo Studio response as returned, so its keys are
  strings. Each generation adds a row, so the creator can compare variants;
  `Core.Studio.choose_draft/2` marks the one they use.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @types ~w(hooks script caption repurpose)

  schema "studio_drafts" do
    field :type, :string
    field :body, :map
    field :chosen, :boolean, default: false
    belongs_to :piece, Core.Studio.Piece
    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc "Draft types: hooks, script, caption, repurpose."
  def types, do: @types

  @doc false
  def changeset(draft, attrs) do
    draft
    |> cast(attrs, [:type, :body])
    |> validate_required([:type, :body])
    |> validate_inclusion(:type, @types)
    # the piece can be deleted (e.g. in another tab) while the AI is writing;
    # this turns the failed insert into an error changeset instead of a raise
    |> foreign_key_constraint(:piece_id)
  end
end

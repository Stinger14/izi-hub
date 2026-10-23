defmodule Core.Studio.Piece do
  @moduledoc """
  One piece of content (video, reel, post or live), from idea to published.

  Context: `changeset/2` covers the fields the creator edits; `user_id`,
  `transcript`, `transcript_srt`, `published_at` and `fb_url` are set by
  `Core.Studio` code, never cast from a form.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @kinds ~w(video reel post live)
  @statuses ~w(idea scripting ready published)
  @languages ~w(es en)

  schema "studio_pieces" do
    field :title, :string
    field :kind, :string, default: "video"
    field :status, :string, default: "idea"
    field :language, :string, default: "es"
    field :notes, :string
    field :transcript, :string
    field :transcript_srt, :string
    field :published_at, :utc_datetime
    field :fb_url, :string

    belongs_to :user, Core.Accounts.User
    has_many :drafts, Core.Studio.Draft
    timestamps(type: :utc_datetime)
  end

  @doc "Content kinds: video, reel, post, live."
  def kinds, do: @kinds

  @doc "Statuses in pipeline order: idea, scripting, ready, published."
  def statuses, do: @statuses

  @doc "Languages the writing helpers support: es, en."
  def languages, do: @languages

  @doc false
  def changeset(piece, attrs) do
    piece
    |> cast(attrs, [:title, :kind, :status, :language, :notes])
    |> validate_required([:title])
    |> validate_length(:title, max: 140)
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:language, @languages)
  end
end

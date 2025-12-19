defmodule Core.Blog.Post do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "posts" do
    field :title, :string
    field :slug, :string
    field :content, :string
    field :excerpt, :string
    field :author, :string
    field :source, :string, default: "custom"
    field :external_url, :string
    field :external_id, :string
    field :points, :integer, default: 0
    field :comments_count, :integer, default: 0
    field :published_at, :naive_datetime
    field :is_published, :boolean, default: false
    field :featured, :boolean, default: false
    field :tags, {:array, :string}, default: []

    belongs_to :user, Core.Accounts.User
    has_many :comments, Core.Blog.Comment

    timestamps()
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [
      :title,
      :slug,
      :content,
      :excerpt,
      :author,
      :source,
      :external_url,
      :external_id,
      :points,
      :comments_count,
      :published_at,
      :is_published,
      :featured,
      :tags,
      :user_id
    ])
    |> validate_required([:title])
    |> validate_length(:title, min: 3, max: 500)
    |> validate_length(:excerpt, max: 500)
    |> validate_inclusion(:source, ["custom", "hackernews"])
    |> generate_slug()
    |> validate_required([:slug])
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:user_id)
  end

  defp generate_slug(changeset) do
    case get_change(changeset, :title) do
      nil ->
        changeset

      title ->
        slug =
          title
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9\s-]/, "")
          |> String.replace(~r/\s+/, "-")
          |> String.trim("-")
          |> String.slice(0, 100)

        # Add timestamp to ensure uniqueness
        unique_slug = "#{slug}-#{:os.system_time(:millisecond)}"
        put_change(changeset, :slug, unique_slug)
    end
  end
end

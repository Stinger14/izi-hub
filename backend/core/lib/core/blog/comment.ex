defmodule Core.Blog.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "comments" do
    field :content, :string
    field :author_name, :string
    field :author_email, :string
    field :is_approved, :boolean, default: false

    belongs_to :post, Core.Blog.Post
    belongs_to :user, Core.Accounts.User
    belongs_to :parent_comment, Core.Blog.Comment

    timestamps()
  end

  @doc false
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [
      :content,
      :author_name,
      :author_email,
      :is_approved,
      :blog_post_id,
      :user_id,
      :parent_comment_id
    ])
    |> validate_required([:content, :blog_post_id])
    |> validate_length(:content, min: 1, max: 1000)
    |> validate_author_info()
    |> foreign_key_constraint(:blog_post_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:parent_comment_id)
  end

  defp validate_author_info(changeset) do
    user_id = get_field(changeset, :user_id)

    if is_nil(user_id) do
      changeset
      |> validate_required([:author_name, :author_email])
      |> validate_format(:author_email, ~r/^[^\s]+@[^\s]+$/)
    else
      changeset
    end
  end
end

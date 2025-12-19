defmodule Core.Portfolio.Project do
  use Ecto.Schema
  import Ecto.Changeset

  schema "projects" do
    field :title, :string
    field :slug, :string
    field :description, :string
    field :long_description, :string
    field :image_url, :string
    field :demo_url, :string
    field :github_url, :string
    field :status, :string, default: "active"
    field :featured, :boolean, default: false
    field :display_order, :integer, default: 0
    field :started_at, :date
    field :completed_at, :date

    belongs_to :user, Core.Accounts.User

    many_to_many :tech_stacks, Core.Portfolio.TechStack,
      join_through: Core.Portfolio.ProjectTechStack,
      on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [
      :title,
      :slug,
      :description,
      :long_description,
      :image_url,
      :demo_url,
      :github_url,
      :status,
      :featured,
      :display_order,
      :started_at,
      :completed_at,
      :user_id
    ])
    |> validate_required([:title, :user_id])
    |> validate_length(:title, min: 3, max: 255)
    |> validate_length(:description, max: 500)
    |> validate_inclusion(:status, ["active", "archived", "draft"])
    |> validate_url(:image_url)
    |> validate_url(:demo_url)
    |> validate_url(:github_url)
    |> generate_slug()
    |> validate_required([:slug])
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:user_id)
  end

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _, value ->
      if value && !String.match?(value, ~r/^https?:\/\//) do
        [{field, "must be a valid URL"}]
      else
        []
      end
    end)
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

        put_change(changeset, :slug, slug)
    end
  end
end

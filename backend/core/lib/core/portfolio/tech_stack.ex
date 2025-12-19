defmodule Core.Portfolio.TechStack do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tech_stacks" do
    field :name, :string
    field :category, :string
    field :icon_url, :string
    field :color, :string
    field :description, :string

    many_to_many :projects, Core.Portfolio.Project, join_through: Core.Portfolio.ProjectTechStack

    timestamps()
  end

  @doc false
  def changeset(tech_stack, attrs) do
    tech_stack
    |> cast(attrs, [:name, :category, :icon_url, :color, :description])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_inclusion(:category, [
      "language",
      "framework",
      "database",
      "tool",
      "cloud",
      "other"
    ])
    |> validate_format(:color, ~r/^#[0-9A-Fa-f]{6}$/, message: "must be a valid hex color")
    |> unique_constraint(:name)
  end
end

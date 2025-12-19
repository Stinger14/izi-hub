defmodule Core.Repo.Migrations.CreateTechStacks do
  use Ecto.Migration

  def change do
    create table(:tech_stacks) do
      add :name, :string
      add :category, :string
      add :icon_url, :string
      add :color, :string
      add :description, :string

      timestamps(type: :utc_datetime)
    end
  end
end

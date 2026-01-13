defmodule Core.Repo.Migrations.CreateTechStacks do
  use Ecto.Migration

  def change do
    create table(:tech_stacks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :category, :string
      add :icon_url, :string
      add :color, :string
      add :description, :string
      timestamps()
    end

    create unique_index(:tech_stacks, [:name])
  end
end

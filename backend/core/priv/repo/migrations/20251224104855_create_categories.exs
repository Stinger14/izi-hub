defmodule Core.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories) do
      add :name, :string
      add :type, :string
      add :color, :string
      add :icon, :string
      add :description, :string

      timestamps(type: :utc_datetime)
    end
  end
end

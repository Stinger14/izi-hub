defmodule Core.Repo.Migrations.CreateProjectTechStacks do
  use Ecto.Migration

  def change do
    create table(:project_tech_stacks) do

      timestamps(type: :utc_datetime)
    end
  end
end

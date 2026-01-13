defmodule Core.Repo.Migrations.CreateProjectTechStacks do
  use Ecto.Migration

  def change do
    create table(:project_tech_stacks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all)
      add :tech_stack_id, references(:tech_stacks, type: :binary_id, on_delete: :delete_all)
      timestamps(updated_at: false)
    end

    create index(:project_tech_stacks, [:project_id])
    create index(:project_tech_stacks, [:tech_stack_id])
    create unique_index(:project_tech_stacks, [:project_id, :tech_stack_id])
  end
end

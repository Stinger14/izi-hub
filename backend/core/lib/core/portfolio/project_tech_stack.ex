defmodule Core.Portfolio.ProjectTechStack do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "project_tech_stacks" do
    belongs_to :project, Core.Portfolio.Project
    belongs_to :tech_stack, Core.Portfolio.TechStack

    timestamps(updated_at: false)
  end
end

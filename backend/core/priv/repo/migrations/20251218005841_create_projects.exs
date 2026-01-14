defmodule Core.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table(:projects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string
      add :slug, :string
      add :description, :string
      add :long_description, :string
      add :demo_url, :string
      add :image_url, :string
      add :github_url, :string
      add :status, :string, default: "active"
      add :featured, :boolean, default: false
      add :display_order, :integer, default: 0
      add :started_at, :date
      add :completed_at, :date
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      timestamps()
    end

    create unique_index(:projects, [:slug])
    create index(:projects, [:user_id])
    create index(:projects, [:status])
    create index(:projects, [:featured])
  end
end

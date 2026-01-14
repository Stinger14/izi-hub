defmodule Core.Repo.Migrations.CreatePageViews do
  use Ecto.Migration

  def change do
    create table(:page_views, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :page_path, :string
      add :referrer, :string
      add :user_agent, :string
      add :country, :string
      add :city, :string
      add :device_type, :string
      add :browser, :string
      add :os, :string
      add :session_id, :string
      add :duration_seconds, :integer
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      timestamps(updated_at: false)
    end

    create index(:page_views, [:user_id])
    create index(:page_views, [:page_path])
    create index(:page_views, [:session_id])
    create index(:page_views, [:device_type])
    create index(:page_views, [:inserted_at])
  end
end

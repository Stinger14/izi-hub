defmodule Core.Repo.Migrations.CreatePageViews do
  use Ecto.Migration

  def change do
    create table(:page_views) do
      add :page_path, :string
      add :referrer, :string
      add :user_agent, :string
      add :country, :string
      add :city, :string
      add :devive_type, :string

      timestamps()
    end
  end
end

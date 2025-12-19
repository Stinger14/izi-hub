defmodule Core.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table(:projects) do
      add :title, :string
      add :slug, :string
      add :description, :string
      add :image_url, :string
      add :github_url, :string
      add :status, :string

      timestamps(type: :utc_datetime)
    end
  end
end

defmodule Core.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string
      add :slug, :string
      add :content, :string
      add :excerpt, :string
      add :author, :string
      add :source, :string, default: "custom"
      add :external_url, :string
      add :external_id, :string
      add :points, :integer, default: 0
      add :comments_count, :integer, default: 0
      add :published_at, :naive_datetime
      add :is_published, :boolean, default: false
      add :featured, :boolean, default: false
      add :tags, {:array, :string}, default: []
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      timestamps()
    end

    create unique_index(:posts, [:slug])
    create index(:posts, [:user_id])
    create index(:posts, [:source])
    create index(:posts, [:published_at])
    create index(:posts, [:is_published])
    create index(:posts, [:featured])
  end
end

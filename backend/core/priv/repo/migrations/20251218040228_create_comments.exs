defmodule Core.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :string
      add :author_name, :string
      add :author_email, :string
      add :is_approved, :boolean, default: false
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :parent_comment_id, references(:comments, type: :binary_id, on_delete: :nilify_all)
      timestamps()
    end

    create index(:comments, [:post_id])
    create index(:comments, [:user_id])
    create index(:comments, [:parent_comment_id])
  end
end

defmodule Core.Repo.Migrations.AddCategoryReferenceTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :category_id, references(:categories, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:transactions, [:category_id])
  end
end
